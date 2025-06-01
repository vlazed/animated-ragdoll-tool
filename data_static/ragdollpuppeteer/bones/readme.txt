Add a text file or a folder containing text files with mappings. 

Requirements:
- Each bone definition text file must consist of a mapping pair in the following form: "bip_pelvis,ValveBiped.Biped01_Pelvis".
    - If the mapping is defined above, the following mapping is also defined: "ValveBiped.Biped01_Pelvis,bip_pelvis", for convenience.
- A folder must contain text files only. Ragdoll Puppeteer will only scan in one level (i.e. `bones/mappings/map.txt` is allowed, but `bones/mappings/subfolder/map.txt` is not allowed) 

Notes:
- Bone names are all case-sensitive!
- Bone definitions take precedence from the character order. If you want your mapping to always take effect, put an exclamation mark in your text file or folder of bone maps.
- If you are missing the default mappings (`roblox`, `valve`, and `vrm`), remove the `bones` folder from `data/ragdollpuppeteer/` and run `ragdollpuppeteer_refreshbones` on the console.

If you have any questions regarding the format of a bone definition, post it in the discussion board:
    
Discussion Board: https://steamcommunity.com/sharedfiles/filedetails/discussions/3333911060