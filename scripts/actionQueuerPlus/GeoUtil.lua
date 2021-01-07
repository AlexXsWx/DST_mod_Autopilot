local GeoUtil = {}

--

function GeoUtil.ManhattanDistance(vecA, vecB)
    return (
        math.abs(vecA.x - vecB.x) +
        math.abs(vecA.y - vecB.y) +
        math.abs(vecA.z - vecB.z)
    )
end

--

function GeoUtil.MapScreenPt(screenX, screenY)
    return Vector3(TheSim:ProjectScreenPos(screenX, screenY))
end

--

-- Returns a function which computes the barycentric coordinates of its input
-- relative to (Origin, A, B), where A-Origin and B-Origin define two directions
function GeoUtil.BarycentricCoordinates(vecOrigin, vecA, vecB)
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
function GeoUtil.CreateTriangleTester(vecOrigin, vecA, vecB)
    local coordsOf = GeoUtil.BarycentricCoordinates(vecOrigin, vecA, vecB)

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
function GeoUtil.CreateQuadrilateralTester(A, B, C, D)
    local tritest1 = GeoUtil.CreateTriangleTester(A, B, C)
    local tritest2 = GeoUtil.CreateTriangleTester(C, D, A)

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
-- and is within the given quad
function GeoUtil.createPositionIterator(quad)

    -- B-----C
    -- |    /.
    -- |   / .
    -- |  /  .
    -- | /   .
    -- A . .(D)
    local A = quad.minXminYProjected
    local B = quad.minXmaxYProjected
    local C = quad.maxXmaxYProjected

    if (
        not A or not B or not C or
        -- TODO: what's this for? is it complete? shouldn't it check coords instead of objects?
        A == B or B == C or
        not quad.maxXminYProjected
    ) then
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

    local moveAlongBC = true

    local function getNextPosition(isPositionSuitable)
        if moveAlongBC then
            while not isPositionSuitable(positionI) do
                positionI = incrementPosition(positionI, paramsBC, step)
                if isOutOfRange(positionI, paramsBC, limitBC) then
                    moveAlongBC = false
                    positionI.x = O.x
                    positionI.z = O.z
                    break
                end
            end
        end

        if not moveAlongBC then
            repeat
                positionI = incrementPosition(positionI, paramsBA, step)
                if isOutOfRange(positionI, paramsBA, limitBA) then
                    return nil
                end
            until isPositionSuitable(positionI)
            limitBC.x = limitBC.x - (O.x - positionI.x)
            limitBC.z = limitBC.z - (O.z - positionI.z)
            O.x = positionI.x
            O.z = positionI.z
            paramsBC.b = positionI.z - paramsBC.k * positionI.x
            moveAlongBC = true
        end

        return positionI
    end

    return getNextPosition
end

--

return GeoUtil
