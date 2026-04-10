local enablePoseSave = CreateConVar(
	"ragdoll_pose_save",
	"1",
	FCVAR_ARCHIVE + FCVAR_REPLICATED,
	"Preserve ragdoll poses between ragdoll physics overrides",
	0,
	1
)

local overrideePoseSave = CreateConVar(
	"ragdoll_pose_save_override",
	"0",
	FCVAR_ARCHIVE + FCVAR_REPLICATED,
	"Always replace ragdoll poses, even if the physics model doesn't change. This fixes weird offsets with resized ragdolls",
	0,
	1
)

local function log(...)
	print(Format("[Ragdoll Pose Save] %s", ...))
end

---@class Pose
---@field pos Vector
---@field ang Angle
---@field scale Vector
---@field parent string

---@class PoseData
---@field transforms {[string]: Pose}
---@field hash string

local BoneToPhysBone, PhysToNonPhys, GetPhysBoneParent
do
	---@alias DefaultBonePose {[1]: Vector, [2]: Angle, [3]: Vector, [4]: Angle}
	---@alias DefaultBonePoseArray DefaultBonePose[]

	---@type table<string, DefaultBonePoseArray> Array of position and angles denoting the reference bone pose
	local defaultPoseTrees = {}

	---Get the pose of every bone of the entity, for nonphysical bone matching
	---@source https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L3550
	---@param ent Entity Entity in reference pose
	---@param identifier string? Custom name for the pose tree to allow for different versions of the same entity
	---@return DefaultBonePoseArray defaultPose Array consisting of a bones offsets from the entity, and offsets from its parent bones
	local function getDefaultBonePoseOf(ent, identifier)
		identifier = identifier or ent:GetModel()
		if defaultPoseTrees[identifier] then
			return defaultPoseTrees[identifier]
		end

		local csModel = ents.CreateClientProp()
		csModel:SetModel(ent:GetModel())
		csModel:DrawModel()
		csModel:SetupBones()
		csModel:InvalidateBoneCache()

		local defaultPose = {}
		local entPos = csModel:GetPos()
		local entAngles = csModel:GetAngles()
		for b = 0, csModel:GetBoneCount() - 1 do
			local parent = csModel:GetBoneParent(b)
			local bMatrix = csModel:GetBoneMatrix(b)
			if bMatrix then
				local pos1, ang1 = WorldToLocal(bMatrix:GetTranslation(), bMatrix:GetAngles(), entPos, entAngles)
				local pos2, ang2 = pos1 * 1, ang1 * 1
				if parent > -1 then
					local pMatrix = csModel:GetBoneMatrix(parent)
					pos2, ang2 = WorldToLocal(
						bMatrix:GetTranslation(),
						bMatrix:GetAngles(),
						pMatrix:GetTranslation(),
						pMatrix:GetAngles()
					)
				end

				-- {Position wrt entity, Angle wrt entity, Position wrt parent, Angle wrt Parent, World aosition, World angle}
				defaultPose[b + 1] = { pos1, ang1, pos2, ang2, bMatrix:GetTranslation(), bMatrix:GetAngles() }
			else
				defaultPose[b + 1] = { vector_origin, angle_zero, vector_origin, angle_zero, vector_origin, angle_zero }
			end
		end

		defaultPoseTrees[identifier] = defaultPose
		csModel:Remove()

		return defaultPose
	end

	---Convert physical transform to manipulate bone transform
	---@source https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L1889
	---@param entity Entity Entity to obtain bone information
	---@param child integer Child bone index
	---@param parent integer Parent bone index
	---@param fPos Vector
	---@param fAng Angle
	---@return Vector positionOffset Position of child bone with respect to parent bone
	---@return Angle angleOffset Angle of child bone with respect to parent bone
	function PhysToNonPhys(entity, child, parent, fPos, fAng)
		local defaultBonePose = getDefaultBonePoseOf(entity)

		local dPos = fPos - defaultBonePose[child + 1][3]

		local m = Matrix()
		m:Translate(defaultBonePose[parent + 1][1])
		m:Rotate(defaultBonePose[parent + 1][2])
		m:Rotate(fAng)

		local _, dAng = WorldToLocal(
			m:GetTranslation(),
			m:GetAngles(),
			defaultBonePose[child + 1][1],
			defaultBonePose[child + 1][2]
		)

		return dPos, dAng
	end

	local boneToPhysMap = {}

	---@param ent Entity Entity to translate bone
	---@param bone integer Bone id
	---@return integer physBone Physics object id
	function BoneToPhysBone(ent, bone)
		local model = ent:GetModel()
		if boneToPhysMap[model] and boneToPhysMap[model][bone] then
			return boneToPhysMap[model][bone]
		else
			boneToPhysMap[model] = boneToPhysMap[model] or {}
			for i = 0, ent:GetPhysicsObjectCount() - 1 do
				local b = ent:TranslatePhysBoneToBone(i)
				if bone == b then
					boneToPhysMap[model][b] = i
					return i
				end
			end
			boneToPhysMap[model][bone] = -1
			return -1
		end
	end

	---@param ent Entity Entity to translate bone
	---@param bone integer Physics object id
	---@return integer b Bone id
	local function PhysBoneToBone(ent, bone)
		return ent:TranslatePhysBoneToBone(bone)
	end

	---@type {[string]: {[integer]: integer}}
	local physBoneParents = {}

	---@param entity Entity Entity to translate bone
	---@param bone integer Physics object id
	---@return integer physBone Parent physics object id
	function GetPhysBoneParent(entity, bone)
		local model = entity:GetModel()
		if physBoneParents[model] and physBoneParents[model][bone] then
			return physBoneParents[model][bone]
		end
		physBoneParents[model] = physBoneParents[model] or {}
		local b = PhysBoneToBone(entity, bone)
		local i = 1
		while true do
			b = entity:GetBoneParent(b)
			local parent = BoneToPhysBone(entity, b)
			if parent >= 0 and parent ~= bone then
				physBoneParents[model][bone] = parent
				return parent
			end
			i = i + 1
			if i > 255 then --We've gone through all possible bones, so we get out.
				break
			end
		end
		physBoneParents[model][bone] = -1
		return -1
	end
end

---Generate a hash using the physics objects. This inherently contains
---the physics object count and order via its convex meshes
---@param entity Entity
local function physicsHash(entity)
	local hash = {}
	for i = 0, entity:GetPhysicsObjectCount() - 1 do
		local po = entity:GetPhysicsObjectNum(i)
		local mesh = po:GetMeshConvexes()
		table.insert(hash, mesh)
	end

	return util.SHA256(util.TableToJSON(hash))
end

if SERVER then
	local hookName = "ragdoll_pose_save"

	local validClasses = {
		prop_ragdoll = true,
	}

	---Forces the entity to build bone positions serverside
	---@param entity Entity
	local function buildEntityBoneCache(entity)
		local d = ents.Create("prop_physics")
		d:SetModel("models/props_junk/watermelon01.mdl")
		d:Spawn()
		d:FollowBone(entity, 0)
		d:SetParent()
		d:Remove()
		entity:RemoveEffects(EF_FOLLOWBONE)
	end

	---Preserve ragdoll pose if and only if the current physics object count differs from the stored count
	---@param ply Player
	---@param entity Entity
	---@param data PoseData
	local function ApplyRagdollPose(ply, entity, data)
		local pose = data
		duplicator.ClearEntityModifier(entity, hookName)

		-- If pose save is disabled, then we don't want to leave it hidden in the newer save
		if not enablePoseSave:GetBool() then
			return
		end

		-- Make sure to only apply poses when the physics model differs
		if overrideePoseSave:GetBool() or (istable(pose) and pose.hash ~= physicsHash(entity)) then
			log("Physics object count differs. Preserving pose for " .. tostring(entity))

			for bone = 0, entity:GetBoneCount() - 1 do
				local name = entity:GetBoneName(bone)
				local p = pose.transforms[name]
				if not p then
					continue
				end

				local pb = BoneToPhysBone(entity, bone)
				local po = entity:GetPhysicsObjectNum(pb)

				-- log("Set " .. name .. " pose")
				if po then
					-- local ppo = entity:GetPhysicsObjectNum(BoneToPhysBone(entity, entity:LookupBone(p.parent)))

					-- local pos, ang = p.pos, p.ang
					-- if ppo then
					-- 	pos, ang = LocalToWorld(pos, ang, ppo:GetPos(), ppo:GetAngles())
					-- else
					-- 	-- print("Recursing")
					-- 	-- print("Start at", name)
					-- 	-- Recurse until the parent bone is physical. Meanwhile, accumulate local transforms for nonphysical bones
					-- 	local walk = p
					-- 	local parentPhysBone = BoneToPhysBone(entity, entity:LookupBone(walk.parent))
					-- 	local i, max = 0, 255
					-- 	while pose.transforms[walk.parent] and parentPhysBone == -1 and i < max do
					-- 		-- print(walk.parent)
					-- 		walk = pose.transforms[walk.parent]
					-- 		pos, ang = LocalToWorld(pos, ang, walk.pos, walk.ang)
					-- 		parentPhysBone = BoneToPhysBone(entity, entity:LookupBone(walk.parent))
					-- 		i = i + 1
					-- 	end
					-- 	-- print("Final parent", walk.parent)

					-- 	ppo = entity:GetPhysicsObjectNum(parentPhysBone)
					-- 	pos, ang = LocalToWorld(pos, ang, ppo:GetPos(), ppo:GetAngles())
					-- end
					po:EnableMotion(true)
					po:Wake()
					po:SetPos(p.worldPos, true)
					po:SetAngles(p.worldAng)
					po:EnableMotion(false)
					po:Wake()
				else
					local pBone = entity:LookupBone(p.parent)

					if pBone then
						-- Calculate on clientside to save some work on server
						net.Start("ragdoll_pose_save_calculate_bone", true)
						net.WriteEntity(entity)
						net.WriteUInt(bone, 8)
						net.WriteUInt(pBone, 8)
						net.WriteVector(p.pos)
						net.WriteAngle(p.ang)
						net.Send(ply)
					end
				end

				entity:ManipulateBoneScale(bone, p.scale)
			end

			duplicator.StoreEntityModifier(entity, hookName, data)
		end
	end

	---@param entity ENTITY
	local function addPoseHooks(entity)
		function entity:PreEntityCopy(...)
			---@type PoseData
			local pose = {
				transforms = {},
				hash = physicsHash(entity),
			}

			buildEntityBoneCache(entity)

			for bone = 0, entity:GetBoneCount() - 1 do
				local boneName = entity:GetBoneName(bone)
				local parent = entity:GetBoneParent(bone)
				local m = entity:GetBoneMatrix(bone)
				local pos, ang = m:GetTranslation(), m:GetAngles()

				if parent >= 0 then
					local pm = entity:GetBoneMatrix(parent)
					local pPos, pAng = pm:GetTranslation(), pm:GetAngles()
					pos, ang = WorldToLocal(pos, ang, pPos, pAng)
					-- Include manipulate bone transforms
					pos, ang = LocalToWorld(
						entity:GetManipulateBonePosition(bone),
						entity:GetManipulateBoneAngles(bone),
						pos,
						ang
					)

					local po = entity:GetPhysicsObjectNum(BoneToPhysBone(entity, bone))

					---@type Pose
					local data = {
						pos = pos,
						ang = ang,
						worldPos = po and po:GetPos(),
						worldAng = po and po:GetAngles(),
						scale = entity:GetManipulateBoneScale(bone),
						parent = entity:GetBoneName(parent),
					}
					pose.transforms[boneName] = data
				else
					local po = entity:GetPhysicsObjectNum(BoneToPhysBone(entity, bone))

					---@type Pose
					local data = {
						pos = pos,
						ang = ang,
						worldPos = po and po:GetPos(),
						worldAng = po and po:GetAngles(),
						scale = entity:GetManipulateBoneScale(bone),
						parent = entity:GetBoneName(parent),
					}
					pose.transforms[boneName] = data
					-- print(boneName)
					-- PrintTable(pose.transforms)
				end
			end

			duplicator.ClearEntityModifier(self, hookName)
			duplicator.StoreEntityModifier(self, hookName, pose)
		end
	end

	duplicator.RegisterEntityModifier(hookName, ApplyRagdollPose)

	hook.Remove("OnEntityCreated", hookName)
	hook.Add("OnEntityCreated", hookName, function(entity)
		---@cast entity ENTITY

		if not enablePoseSave:GetBool() then
			return
		end
		timer.Simple(0, function()
			if IsValid(entity) and not entity:CreatedByMap() and validClasses[entity:GetClass()] then
				addPoseHooks(entity)
			end
		end)
	end)

	util.AddNetworkString("ragdoll_pose_save_calculate_bone")
	net.Receive("ragdoll_pose_save_calculate_bone", function(len, ply)
		local entity = net.ReadEntity()
		local bone = net.ReadUInt(8)
		local pos = net.ReadVector()
		local ang = net.ReadAngle()

		entity:ManipulateBonePosition(bone, pos)
		entity:ManipulateBoneAngles(bone, ang)
	end)
else
	net.Receive("ragdoll_pose_save_calculate_bone", function(len, ply)
		local entity = net.ReadEntity()
		local bone = net.ReadUInt(8)
		local pBone = net.ReadUInt(8)
		local fPos = net.ReadVector()
		local fAng = net.ReadAngle()

		local pos, ang = PhysToNonPhys(entity, bone, pBone, fPos, fAng)

		net.Start("ragdoll_pose_save_calculate_bone", true)
		net.WriteEntity(entity)
		net.WriteUInt(bone, 8)
		net.WriteVector(pos)
		net.WriteAngle(ang)
		net.SendToServer()
	end)
end
