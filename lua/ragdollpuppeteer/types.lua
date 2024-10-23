---@meta
--- Used for the developer to help with typing

local types = {}

-- Stop Motion Helper Types

---@alias SMHModifiers
---| "advcamera"
---| "advlight"
---| "bodygroup"
---| "bones"
---| "color"
---| "eyetarget"
---| "flex"
---| "modelscale"
---| "physbones"
---| "poseparameter"
---| "position"
---| "skin"
---| "softlamps"
---| "ragdollpuppeteer"
---All known fields controlled by SMH, including the custom ragdollpuppeteer modifier

---@class SMHTimelineMod An array of timeline modifiers
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
---@field ["14"] "ragdollpuppeteer"
---@field KeyColor Color

---@class SMHFramePose A struct of the entity's pose at an SMH frame and metadata related to it
---@field Ang Angle
---@field Pos Vector
---@field LocalAng Angle?
---@field LocalPos Vector?
---@field RootAng Angle?
---@field RootPos Vector?
---@field Moveable boolean?
---@field Scale Vector

---@class SMHColorPose A struct of the entity's color at an SMH frame
---@field Color Color

---@class SMHModifier A struct of the entity's modifiers
---@field physbones SMHFramePose[]?
---@field bones SMHFramePose[]?
---@field color SMHColorPose?

---@class SMHFrameData The data shown in the SMH Timeline for the selected entity
---@field EntityData SMHModifier
---@field EaseIn number
---@field EaseOut number
---@field Modifier SMHModifiers
---@field Position number

---@alias SMHTimelineMods SMHTimelineMod[]

---@class SMHProperties The animation properties of the entity
---@field TimelineMods SMHTimelineMods An array of timeline modifiers
---@field Class string The entity class
---@field Timelines number The count of timelines
---@field Name string The unique name of the entity, different from the model name
---@field Model string The model path of the entity

---@class SMHData The animation data for each entity
---@field Frames SMHFrameData[] An array of the data seen in the SMH timeline
---@field Model string The model path of the entity
---@field Properties SMHProperties The animation properties of the entity

---@class SMHFile The text file containing SMH animation data
---@field Map string The map where the animation takes place
---@field Entities SMHData[] The animation data for each entity

--- UI Types

---@class BoneTreeNode: DTree_Node
---@field locked boolean
---@field boneIcon string
---@field boneId integer

---@class PoseParameterSlider
---@field slider DNumSlider
---@field name string

---@class FrameSlider: DNumSlider
---@field prevFrame number

---@class PanelChildren An immutable struct of the CPanel's panels. Frontend interface for the user to control the puppeteer
---@field angOffset DNumSlider[]
---@field puppetLabel DLabel
---@field smhBrowser DFileBrowser
---@field smhList DListView
---@field sequenceList DListView
---@field sequenceList2 DListView
---@field sequenceSheet DPropertySheet
---@field nonPhysCheckBox DCheckBoxLabel
---@field baseSlider FrameSlider
---@field gestureSlider FrameSlider
---@field searchBar DTextEntry
---@field sourceBox DComboBox
---@field poseParams PoseParameterSlider[]
---@field boneTree DTree
---@field showPuppeteer DCheckBoxLabel
---@field removeGesture DButton
---@field floorCollisions DCheckBoxLabel
---@field recoverPuppeteer DButton
---@field playButton DButton
---@field fpsWang DNumberWang
---@field heightOffset DNumSlider
---@field puppeteerColor DColorCombo
---@field puppeteerIgnoreZ DCheckBoxLabel
---@field attachToGround DCheckBoxLabel
---@field anySurface DCheckBoxLabel
---@field incrementGestures DCheckBoxLabel

---@class PanelProps An immutable struct of the CPanel's properties
---@field puppet Entity The prop or ragdoll controlled by the puppeteer
---@field physicsCount integer The number of physics objects, passed from the server
---@field puppeteer Entity The prop or ragdoll pose controller
---@field basePuppeteer Entity A puppeteer at the first frame of animation, for root offsetting
---@field gesturer Entity A puppeteer for additive sequence layering
---@field baseGesturer Entity A gesturer at the first frame of animation, to help enable additive sequence layering
---@field viewPuppeteer Entity A puppeteer shown to the player. Can be resized
---@field model string The puppet or puppeteer's model path
---@field floor PuppeteerFloor The floor to control puppeteer offsetting

---@class PanelState A mutable struct of the CPanel's values at a specific time, influenced by the environment and player actions
---@field maxFrames integer The duration of the animation
---@field previousPuppeteer Entity? The last puppeteer used before the current one
---@field defaultBonePose DefaultBonePoseArray An array of bone poses in the reference pose
---@field physicsObjects PhysicsObject[] An array  of physics objects in the puppet

-- Miscellaneous Types

---@class ResizedBoneOffset
---@field posoffset Vector
---@field angoffset Angle

---@class PhysBone
---@field parentid integer

---@class ResizedRagdoll: Entity Ragdoll Resizer entity (prop_resizedragdoll_physparent)
---@field PhysObjScales Vector[] An array of the scales for each physics object
---@field SavedBoneMatrices VMatrix[] The bone matrices from the ragdoll's BuildBonePosition function
---@field BoneOffsets ResizedBoneOffset[] An array of ResizedBoneOffset containing the position offset and angle offset of each nonphysical bone
---@field ClassOverride "prop_resizedragdoll_physparent" The true classname found in the entity's filename
---@field PhysBones PhysBone[] A sparse array indicating which bone index is a physbone
---@field PhysBoneOffsets Vector[] An array of position offsets for the physbones
---@field GetStretch fun(self: Entity|ResizedRagdoll): boolean A check for whether the ResizedRagdoll is stretchy

---@class RagdollPuppeteerPlayerField A hashmap of the player's ragdoll puppeteer settings, keyed by Player:UserID()
---@field player Player The player with the Player:UserID()
---@field puppet Entity The player's puppet
---@field puppeteer Entity The player's serverside puppeteer
---@field physicsCount integer The number of physics objects on the puppet
---@field currentIndex integer The sequence id of the puppeteer
---@field cycle number The frame of the puppeteer's sequence
---@field fps integer The framerate of the puppeteer's animation
---@field bonesReset boolean Whether the puppeteer has reset its bones before
---@field filteredBones integer[] A sparse array of bones that will not be posed
---@field floor PuppeteerFloor The platform for offsetting the puppeteer
---@field lastPose BonePoseArray An array of BonePose used when the bone position and angles can't be obtained
---@field animateNonPhys boolean Whether to use ManipulateBonePosition/Angles/Scale on the puppet
---@field poseParams table<number> An array of pose parameter values, keyed by the pose parameter id
---@field playbackEnabled boolean Whether the player is animating the puppeteer. Tracked for moving the puppet accurately

---@class RagdollPuppeteer: Entity The pose controller of the ragdoll/prop puppet
---@field ragdollpuppeteer_currentMaterial IMaterial The current puppeteer material to pass to the PuppeteerFloor

---@alias DefaultBonePose table<Vector, Angle, Vector, Angle>
---@alias DefaultBonePoseArray DefaultBonePose[]
---@alias BonePose table<Vector, Angle>
---@alias BonePoseArray BonePose[]

---@class PhysicsObject
---@field parent integer

---@class PuppeteerFloor: Entity The platform that offsets the puppeteer
---@field puppeteers Entity[] An array of puppeteers
---@field puppet Entity The puppet to be controlled by the puppeteer
---@field floorSize Vector[] The size of the floor based on the puppeteer
---@field angleOffset Angle The angle offset to apply on the puppeteers with respect to the floor
---@field SetAngleOffset fun(self: PuppeteerFloor, angle: Angle) A setter for angleOffset
---@field SetPhysicsSize fun(self: PuppeteerFloor, puppeteer: Entity) A setter for floorSize
---@field AddPuppeteers fun(self: PuppeteerFloor, puppeteers: Entity[]) Insert into the puppeteers array
---@field SetPuppet fun(self: PuppeteerFloor, puppet: Entity) A setter for the PuppeteerFloor's puppet
---@field RemovePuppeteers fun(self: PuppeteerFloor) Remove puppeteers from the world
---@field ClearPuppeteers fun(self: PuppeteerFloor) Clear the puppeteer table
---@field SetPlayerOwner fun(self: PuppeteerFloor, ply: Player) A setter for the PuppeteerFloor's player owner
---@field SetPuppeteerRootScale fun(self: PuppeteerFloor, newScale: Vector) A setter for the root scale, used for Ragdoll Resizer entities
---@field GetPuppeteerRootScale fun(self: PuppeteerFloor): puppeteerRootScale: Vector A getter for the root scale, used for Ragdoll Resizer entities

return types
