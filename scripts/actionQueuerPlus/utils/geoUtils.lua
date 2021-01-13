local logger = require "actionQueuerPlus/utils/logger"

local geoUtils = {}

--

function geoUtils.ManhattanDistance(vecA, vecB)
    return (
        math.abs(vecA.x - vecB.x) +
        math.abs(vecA.y - vecB.y) +
        math.abs(vecA.z - vecB.z)
    )
end

--

function geoUtils.MapScreenPt(screenX, screenY)
    return Vector3(TheSim:ProjectScreenPos(screenX, screenY))
end

--

-- Returns a function which computes the barycentric coordinates of its input
-- relative to (Origin, A, B), where A-Origin and B-Origin define two directions
function geoUtils.BarycentricCoordinates(vecOrigin, vecA, vecB)
    local dirA = vecA - vecOrigin
    local dirB = vecB - vecOrigin

    local dotBB = dirB:Dot(dirB)
    local dotBA = dirB:Dot(dirA)
    local dotAA = dirA:Dot(dirA)

    local scale = 1 / (dotBB * dotAA - dotBA * dotBA)

    return function(vecGlobal)
        local vecLocal = vecGlobal - vecOrigin

        local dotBLocal = dirB:Dot(vecLocal)
        local dotALocal = dirA:Dot(vecLocal)

        local u = (dotAA * dotBLocal - dotBA * dotALocal) * scale
        local v = (dotBB * dotALocal - dotBA * dotBLocal) * scale

        return u, v
    end
end

-- Returns a function which tests if a point is in a given triangle
function geoUtils.CreateTriangleTester(vecOrigin, vecA, vecB)
    local coordsOf = geoUtils.BarycentricCoordinates(vecOrigin, vecA, vecB)

    return function(vec)
        local u, v = coordsOf(vec)
        return u >= 0 and v >= 0 and u + v <= 1
    end
end

-- Returns a function which tests if a point is in a given quadrilateral
-- AC and BD must be the diagonals, e.g.
--
--   D --- C
--   | \   |
--   |  \  |
--   |   \ |
--   A --- B
--
function geoUtils.CreateQuadrilateralTester(A, B, C, D)
    local tritest1 = geoUtils.CreateTriangleTester(A, B, C)
    local tritest2 = geoUtils.CreateTriangleTester(C, D, A)

    return function(vec)
        return tritest1(vec) or tritest2(vec)
    end
end

--

-- solves y = k*x + b for k and b for XZ plane
local function calcLineParam(vecEnd, vecStart)
    local k, b
    if vecStart.x == vecEnd.x then
        k = 0
        b = vecStart.x        
    else
        k = (vecEnd.z - vecStart.z) / (vecEnd.x - vecStart.x)
        b = vecEnd.z - k * vecEnd.x
    end
    return k, b
end

--

local ORIENTATION = {
    OTHER      = 0,
    VERTICAL   = 1,
    HORIZONTAL = 2
}

local function tryGetPerpendicular(orientation)
    if orientation == ORIENTATION.VERTICAL then
       return ORIENTATION.HORIZONTAL
    end
    if orientation == ORIENTATION.HORIZONTAL then
        return ORIENTATION.VERTICAL
    end
    return orientation 
end

local function checkLineOrientation(p1, p2)
    local eps = 0.5
    if math.abs(p2.x - p1.x) < eps then
        return ORIENTATION.VERTICAL
    elseif math.abs(p2.z - p1.z) < eps then 
        return ORIENTATION.HORIZONTAL
    else 
        return ORIENTATION.OTHER
    end
end

local function getLineParams(p1, p2)
    local k, b = calcLineParam(p1, p2)
    return {
        orientation = checkLineOrientation(p1, p2),
        directionX = p1.x < p2.x and 1 or -1,
        directionZ = p1.z < p2.z and 1 or -1,
        k = k,
        b = b,
    }
end

-- WARNING: this function mutates the `outVec`
local function incrementPosition(outVec, lineParams, step)
    if lineParams.orientation == ORIENTATION.VERTICAL then
        outVec.z = outVec.z + step * lineParams.directionZ
    elseif lineParams.orientation == ORIENTATION.HORIZONTAL then
        outVec.x = outVec.x + step * lineParams.directionX
    else 
        outVec.x = outVec.x + step * lineParams.directionX
        outVec.z = lineParams.k * outVec.x + lineParams.b
    end
    return outVec
end

local function isOutOfRange(vec, lineParams, vecLimit)
    local tolerance = 0.3
    return (
        lineParams.orientation == ORIENTATION.VERTICAL and (
            lineParams.directionZ ==  1 and vec.z > vecLimit.z + tolerance or
            lineParams.directionZ == -1 and vec.z < vecLimit.z - tolerance
        ) or
        lineParams.orientation == ORIENTATION.HORIZONTAL and (
            lineParams.directionX ==  1 and vec.x > vecLimit.x + tolerance or
            lineParams.directionX == -1 and vec.x < vecLimit.x - tolerance
        ) or (
            lineParams.directionZ ==  1 and vec.z > vecLimit.z + tolerance or
            lineParams.directionZ == -1 and vec.z < vecLimit.z - tolerance or
            lineParams.directionX ==  1 and vec.x > vecLimit.x + tolerance or
            lineParams.directionX == -1 and vec.x < vecLimit.x - tolerance
        )
    )
end

-- Returns a function that on each call returns a new position that fulfills given criteria
-- and is within the given selection area
function geoUtils.createPositionIterator(selectionBox)

    -- if (
    --     not selectionBox.startPos or
    --     not selectionBox.endPos
    -- ) then
    --     return nil
    -- end

    -- 0:0 = bottom left corner
    local minX = math.min(selectionBox.startPos.x, selectionBox.endPos.x)
    local maxX = math.max(selectionBox.startPos.x, selectionBox.endPos.x)
    local minY = math.min(selectionBox.startPos.y, selectionBox.endPos.y)
    local maxY = math.max(selectionBox.startPos.y, selectionBox.endPos.y)

    -- each tile has a side of 4 units
    -- geometric placement makes 8x8 points per tile

    --     North
    -- -Z  _   _ -X
    --    |\   /|
    --      \ /
    --       X     East
    --      / \
    --    |/   \|
    -- +X        +Z

    -- B-----C
    -- |    /.
    -- |   / .
    -- |  /  .
    -- | /   .
    -- A . .(D)

    -- TODO: consider keeping 90deg angles
    local A = geoUtils.MapScreenPt(minX, minY)
    local B = geoUtils.MapScreenPt(minX, maxY)
    local C = geoUtils.MapScreenPt(maxX, maxY)

    -- TODO: what's this for? is it complete? shouldn't it check coords instead of objects?
    if A == B or B == C then
        return nil
    end

    local O       = Vector3(B:Get())
    local limitBC = Vector3(C:Get())
    local limitBA = A

    local paramsBA = getLineParams(B, A)
    local paramsBC = getLineParams(B, C)
    paramsBA.orientation = tryGetPerpendicular(paramsBC.orientation)
    paramsBC.orientation = tryGetPerpendicular(paramsBA.orientation)

    local positionI = Vector3(O:Get())
    local step = (paramsBA.orientation == ORIENTATION.OTHER) and 0.5 or 0.25

    local first = true
    local moveAlongBC = true

    local function acceptPosition()
        if not moveAlongBC then
            limitBC.x = limitBC.x - (O.x - positionI.x)
            limitBC.z = limitBC.z - (O.z - positionI.z)
            O.x = positionI.x
            O.z = positionI.z
            paramsBC.b = positionI.z - paramsBC.k * positionI.x
            moveAlongBC = true
        end
    end

    local function getNextPosition()

        if first then
            first = false
            return positionI, acceptPosition
        end

        if moveAlongBC then
            positionI = incrementPosition(positionI, paramsBC, step)
            if isOutOfRange(positionI, paramsBC, limitBC) then
                moveAlongBC = false
                positionI.x = O.x
                positionI.z = O.z
            end
        end

        if not moveAlongBC then
            positionI = incrementPosition(positionI, paramsBA, step)
            if isOutOfRange(positionI, paramsBA, limitBA) then
                return nil
            end
        end

        return positionI, acceptPosition
    end

    return getNextPosition
end

-- Returns a function that on each call returns a new position that fulfills given criteria
-- and is within the given selection area
function geoUtils.createPositionIterator2(selectionBox)

    local shortSideFirst = false
    local longSideFirst = false
    local limitToSelectionBox = false
    local boundsTolerance = 0.3

    -- Compare floats with given precision
    local function equals(a, b, optEpsilon)
        return math.abs(a - b) <= (optEpsilon or 1e-6)
    end

    -- input values in range -180..180
    local function getShortestAngleBetween(angle1Deg, angle2Deg)
        if equals(angle1Deg, angle2Deg) then return 0 end
        -- -1..1
        local relativeDiff = (angle2Deg - angle1Deg) / 360
        return 360 * (relativeDiff - math.floor(relativeDiff + 0.5))
    end

    local function round(value)
        local toRound = value
        local remainder = toRound % 1
        local rounded = toRound - remainder
        if remainder >= 0.5 then
            rounded = rounded + 1
        end
        return rounded
    end

    -- @example
    -- roundBase(40, 20) -- 40
    -- roundBase(41, 20) -- 40
    -- roundBase(42, 20) -- 40
    -- roundBase(55, 20) -- 60
    -- roundBase(60, 20) -- 60
    local function roundBase(value, base, optOffset)
        if equals(base, 0) then
            return value
        end
        local offset = optOffset or 0
        return offset + base * round((value - offset) / base)
    end

    local function roundedVec(vec)
        return Vector3(
            roundBase(vec.x, 0.5),
            0,
            roundBase(vec.z, 0.5)
        )
    end

    logger.logDebug("selection box start " .. selectionBox.startPos.x .. ":" .. selectionBox.startPos.y)
    logger.logDebug("selection box end   " .. selectionBox.endPos.x   .. ":" .. selectionBox.endPos.y)

    local startPos = geoUtils.MapScreenPt(selectionBox.startPos.x, selectionBox.startPos.y)
    local endPos   = geoUtils.MapScreenPt(selectionBox.endPos.x,   selectionBox.endPos.y)
    local corner1  = geoUtils.MapScreenPt(selectionBox.endPos.x,   selectionBox.startPos.y)
    local corner2  = geoUtils.MapScreenPt(selectionBox.startPos.x, selectionBox.endPos.y)

    logger.logDebug("startPos " .. startPos:__tostring())
    logger.logDebug("endPos   " .. endPos:__tostring())
    logger.logDebug("corner1  " .. corner1:__tostring())
    logger.logDebug("corner2  " .. corner2:__tostring())

    local isBounded = geoUtils.CreateQuadrilateralTester(startPos, corner1, endPos, corner2)

    local len1 = math.max(
        (corner1 - startPos):Length(),
        (endPos  - corner2):Length()
    )

    local len2 = math.max(
        (corner2 - startPos):Length(),
        (endPos - corner1):Length()
    )

    startPos = roundedVec(startPos)
    endPos   = roundedVec(endPos)
    corner1  = roundedVec(corner1)
    corner2  = roundedVec(corner2)

    local direction1 = corner1 - startPos
    local direction2 = corner2 - startPos

    if (
        shortSideFirst and len2 < len1 or
        longSideFirst and len2 > len1
    ) then
        logger.logDebug("flip corner1<->corner2")
        corner1,    corner2    = corner2,    corner1
        direction1, direction2 = direction2, direction1
        len1,       len2       = len2,       len1
    end

    logger.logDebug("direction1 = " .. direction1:__tostring())
    local angle1Deg = roundBase(
        180 * math.atan2(direction1.z, direction1.x) / PI,
        45
    )
    logger.logDebug("angle1Deg (aligned) = " .. angle1Deg)
    direction1.x = len1 * math.cos(PI * angle1Deg / 180)
    direction1.z = len1 * math.sin(PI * angle1Deg / 180)
    logger.logDebug("direction1 (realigned) = " .. direction1:__tostring())
    direction1:Normalize()

    logger.logDebug("direction2 = " .. direction2:__tostring())
    direction2:Normalize()
    local angle2Deg = 180 * math.atan2(direction2.z, direction2.x) / PI
    logger.logDebug("angle2Deg = " .. angle2Deg)
    if getShortestAngleBetween(angle1Deg, angle2Deg) > 0 then
        angle2Deg = angle1Deg + 90
    else
        angle2Deg = angle1Deg - 90
    end
    logger.logDebug("angle2Deg (realigned) = " .. angle2Deg)

    local worldStep = ((angle1Deg + 360) % 45) % 2 == 0 and 0.5 or math.sqrt(0.5)

    local iIncrement = -1
    local iResetMin = 0 -- 1e309 -- aka inf
    local iResetMax = 0
    local i = 0
    local j = -1

    local lastPosition = startPos
    local lastI = 0
    local lastJ = 0
    local flipDirectionAfterCurrentLine = true

    local function acceptPosition()
        flipDirectionAfterCurrentLine = true
        iResetMin = math.min(lastI, iResetMin)
        iResetMax = math.max(lastI, iResetMax)
        logger.logDebug(
            "accepted position " .. lastI .. ":" .. lastJ ..
            " min = " .. iResetMin .. " max = " .. iResetMax
        )
    end

    local function getNextPosition()
        local position = nil
        while true do
            i = i + iIncrement
            local outOfBounds = false
            if i == -1 then
                logger.logDebug("out of bounds: i == -1")
                outOfBounds = true
            end
            if i * worldStep > len1 + boundsTolerance then
                logger.logDebug("out of bounds: i * worldStep > len1 + boundsTolerance")
                outOfBounds = true
            end
            if outOfBounds then
                -- start new line
                -- i
                if flipDirectionAfterCurrentLine then
                    flipDirectionAfterCurrentLine = false
                    iIncrement = -iIncrement
                    logger.logDebug("new increment = " .. iIncrement)
                end
                if iIncrement == 1 then
                    i = iResetMin
                    logger.logDebug("i = min = " .. i)
                else
                    i = iResetMax
                    logger.logDebug("i = max = " .. i)
                end
                -- j
                j = j + 1
                if j * worldStep > len2 + boundsTolerance then
                    logger.logDebug("out of bounds: j * worldStep > len2 + boundsTolerance")
                    return nil
                end
            end
            position = roundedVec(
                lastPosition +
                (direction1 * (i - lastI) * worldStep) +
                (direction2 * (j - lastJ) * worldStep)
            )
            local debugStr = (
                "pos (" .. lastI .. ":" .. lastJ .. ") -> " .. i .. ":" .. j ..
                " = " .. position:__tostring()
            )
            lastPosition = position
            lastI = i
            lastJ = j
            if not limitToSelectionBox or isBounded(position) then
                logger.logDebug(debugStr .. " - try")
                return position, acceptPosition
            else
                logger.logDebug(debugStr .. " is out of selection box")
            end
        end
    end

    return getNextPosition
end

--

return geoUtils
