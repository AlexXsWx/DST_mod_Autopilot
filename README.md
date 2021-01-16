# Origin

This mod is a rewrite and extending of [ActionQueue(DST)](https://steamcommunity.com/sharedfiles/filedetails/?id=609051112) v1.3.6 by simplex and then xiaoXzzz  
It is also using some bits of code and ideas from [ActionQueue Reborn](https://steamcommunity.com/sharedfiles/filedetails/?id=1608191708) by eXiGe  

# Description

Queue a sequence of actions (such as chopping, mining, picking up, planting etc) by holding Shift (can be changed in config) and clicking on stuff or selecting area.

# Changes

* Auto scare birds and pick up seeds when planting stuff
* Shift + double click to select given entity type within some radius
* Speed up chopping and digging
* Support werebeaver form
* Support Wormwood's ability to plant seeds anywhere
* Partial support for new farming (tilling, fertilizing and watering is not supported yet)
* Change any configuration of the mod on the fly
* Configurable pick up filters, e.g. to prevent picking up flowers
* Add more actions like repairing leaks and healing
* Alternate queuing key allows to queue actions on yourself (like eating seeds or healing with spider glands)
* Fix actions being interrupted without an intent, like when scrolling map, browsing recipes or reorganizing inventory
* Allow to deselect area
* Explicit key to interrupt actions so you can keep your exact position
* Fix selection being submitted without releasing mouse button
* Allow queuing certain actions (e.g. assessing plants) with direct clicking only
* Other bug fixes & more
* Improve code maintainability by splitting it into more files and components

# Known issues

* Auto collect does not respect filters
* Werebeaver speed when digging tree stumps is not always optimal
* When using Shift for the mod, drop action by clicking with an item on character while holding Shift doesn't work

# Source code

https://github.com/AlexXsWx/DST_mod_Autopilot
