local modules = {}

---@alias SMHModifiers "advcamera" | "advlight" | "bodygroup" | "bones" | "color" | "eyetarget" | "flex" | "modelscale" | "physbones" | "poseparameter" | "position" | "skin" | "softlamps"

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
---@field EntityData SMHModifier[]
---@field EaseIn number
---@field EaseOut number
---@field Modifier SMHModifiers
---@field Position number

---@class SMHData
---@field Frames SMHFrameData[]
---@field Class string
---@field Timelines integer
---@field Name string
---@field Model string

---@class SMHFile
---@field Map string
---@field Entities SMHData[]

return modules
