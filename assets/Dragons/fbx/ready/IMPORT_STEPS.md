# Import the pilot dragons (Cinderwing, 4 files)

Files in this folder: `Cinderwing_Hatchling.fbx`, `Cinderwing_Drake.fbx`, `Cinderwing_Dragon.fbx`, `Cinderwing_Elder.fbx`.
Each FBX holds ONE skinned mesh named `Body`, the standard 35-bone dragon skeleton, and ONE embedded base-color texture.
It's already exported in studs, facing forward, with its feet at 0. Claude can't import FBX through the Studio MCP, so
this part is by hand. It takes about 5 minutes.

## Before you start

- Open **Bind a Dragon** (place 137760768456092) in Studio **signed in as the account that owns the place** (user id
  8632543632, the place's creator). Meshes and textures are uploaded to the account that is signed in. Uploaded from
  another account, the game may not be allowed to load them.
- Edit mode (not Play). Rojo doesn't need to be connected.

## Steps

1. Click **Home tab → Import** (the box icon between Script and Material; older Studio versions call it File → Import 3D).
   Don't use the Avatar-tab importer (it forces avatar rigs), and don't use the Asset Manager's Import button (it only
   uploads files and doesn't place the models in Workspace).
2. In the file picker go to `E:\Roblox\Bind a Dragon\assets\Dragons\fbx\ready\`. Select **all four** `Cinderwing_*.fbx`
   (Ctrl+click) and press **Open**. The 3D Importer lists the four files on the left.
3. For **each** of the four files, click the **top item of that file** (the file name, not a bone or the mesh). The right
   panel then shows the whole file's settings. Set:
   - **Rig General → Rig Type: Custom**. This keeps the dragon skeleton. Don't use No Rig, R15 or Rthro.
   - **File General → Anchored: on**, **Import Only As Model: on**, **Insert In Workspace: on**.
   - **File General → Insert Using Scene Position: off**. **Set Pivot To Scene Origin: on**, if shown.
   - **File Dimensions → Scale Unit: Stud**, if shown. The files are in studs; Claude resizes each model to its stage
     length afterwards anyway.
   - **File Transform → World Forward: Front, World Up: Top**. These are the defaults; leave them.
   - Leave **Merge Meshes** off and keep the textures/materials import on (default).

   These are the settings used for the Star Merchant import. If a label reads a little differently in your Studio
   version, the goal is the same: skinned mesh with its bones kept (Custom rig), texture imported, one model per file.
4. Check the preview: each dragon shows its texture. It stands upright and faces the preview's front. If a file
   shows a warning about bones or skinning, write it down.
5. Press **Import**. Studio uploads the meshes and textures. Four Models appear in Workspace, named
   `Cinderwing_Hatchling`, `Cinderwing_Drake`, `Cinderwing_Dragon`, `Cinderwing_Elder`.
6. Quick check: expand one model in the Explorer. It should hold a MeshPart `Body`, and under `Body` about **35 `Bone`**
   entries (`Root`, `Spine1`, `Neck1`, `Head`, `Tail1` ... `Wing_L_Upper` ...). Don't move, rename or resize anything.
7. **Save the place** (File → Save to Roblox), then tell Claude **"pilot imported"**. Claude moves them into
   `ReplicatedStorage.Assets.Dragons.Cinderwing.<Stage>` and sets them up (step 2).

## If the upload is slow or a dragon is grey

- Textures go through Roblox moderation. A model can stay **grey or untextured for a few minutes** after the import.
  This is normal: wait 5-10 minutes; don't import the same file again (that only uploads a second copy).
- If the Output window shows **"Failed to upload"** or a texture is still grey after ~15 minutes, tell Claude which file.
  Usually re-importing just that one file fixes it.
- A file that refuses to import: tell Claude the exact message. Every file can be re-exported (the source GLBs are
  never changed).
