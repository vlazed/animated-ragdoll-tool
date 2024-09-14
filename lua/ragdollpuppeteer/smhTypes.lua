local modules = {}

---@alias SMHModifiers "advcamera" | "advlight" | "bodygroup" | "bones" | "color" | "eyetarget" | "flex" | "modelscale" | "physbones" | "poseparameter" | "position" | "skin" | "softlamps"

---@class SMHTimelineMod
---@field ["1"] "bones"
---@field ["2"] "color"
---@field ["3"] "bodygroup"
---@field ["4"] "modelscale"
---@field ["5"] "softlamps"
---@field ["6"] "poseparameter"
---@field ["7"] "position"
---@field ["8"] "skin"
---@field ["9"] "eyetarget"
---@field ["10"] "advcamera"
---@field ["11"] "physbones"
---@field ["12"] "flex"
---@field ["13"] "advlights"
---@field KeyColor Color

---@class SMHFramePose
---@field Ang Angle
---@field Pos Vector
---@field LocalAng Angle?
---@field LocalPos Vector?
---@field Moveable boolean?
---@field Scale Vector

---@class SMHColorPose
---@field Color Color

---@class SMHModifier
---@field physbones SMHFramePose[]?
---@field bones SMHFramePose[]?
---@field color SMHColorPose?

---@class SMHFrameData
---@field EntityData SMHModifier
---@field EaseIn number
---@field EaseOut number
---@field Modifier SMHModifiers
---@field Position number

---@alias SMHTimelineMods SMHTimelineMod[]

---@class SMHProperties
---@field TimelineMods SMHTimelineMods
---@field Class string
---@field Timelines number
---@field Name string
---@field Model string

---@class SMHData
---@field Frames SMHFrameData[]
---@field Model string
---@field Properties SMHProperties

---@class SMHFile
---@field Map string
---@field Entities SMHData[]

return modules
