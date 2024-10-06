
# CfgPatches to ModID Mapper

This script is designed to scan Arma 3 `.pbo` files within a mods directory, extract `CfgPatches` entries, and map them to the corresponding Steam Workshop mod ID and name. The results are saved in an SQF array format, making it easy to search for `CfgPatches` entries and find the associated mod name and ID.

## Features

- Scans `.pbo` files in a specified directory.
- Extracts `CfgPatches` entries from the files.
- Maps `CfgPatches` entries to Steam Workshop mod IDs.
- Retrieves mod names from Steam Workshop pages.
- Outputs the mapping in an SQF array format.
- Processes files in parallel for improved performance.
- Handles invalid mod IDs and missing data gracefully.
- Provides informative logging for errors and progress.

## Requirements

- Linux (Tested on Ubuntu)
- GNU Parallel
- `curl`
- `strings`
- `grep`

## Installation

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/yourusername/cfgpatches-modid-mapper.git
   cd cfgpatches-modid-mapper
   ```

2. **Make the Script Executable:**

   ```bash
   chmod +x map_cfgpatches.sh
   ```

3. **Install Dependencies:**

   Make sure the following packages are installed:

   - GNU Parallel
   - curl
   - grep (with support for `-F` and `-x` options)
   - strings

   To install the required dependencies on Ubuntu:

   ```bash
   sudo apt-get update
   sudo apt-get install parallel curl binutils
   ```

## Usage

1. **Prepare Your `CfgPatches` SQF File:**

   The input file should contain an array of `CfgPatches` entries in SQF format. Example:

   ```sqf
   [
   "Core", "A3Data", "A3_Functions_F", "A3_Functions_F_EPA", "CUP_Air_Data"
   ]
   ```

2. **Run the Script:**

   Run the script, providing the path to your SQF file and optionally the mods directory:

   ```bash
   ./map_cfgpatches.sh path/to/your/file.sqf [mods_directory]
   ```

   Example:

   ```bash
   ./map_cfgpatches.sh CfgPatches/CfgPatches06102024.sqf /home/steam/.steam/steamcmd/arma3_windows/clientmods/
   ```

3. **Output:**

   The script will output the mapping to `cfgpatches_mappings.sqf` in the following format:

   ```sqf
   [
     ["Core", "Mod Name", "Mod ID"],
     ["A3Data", "", ""],
     ["CUP_Air_Data", "CUP Vehicles", "583496184"],
     ...
   ]
   ```

   If a `CfgPatches` entry is not found in any mod, the mod name and ID will be left empty.

## Error Handling

- If a mod name cannot be retrieved from the Steam Workshop, the script will log the URL and mark the mod name as `"Unknown"`.
- Invalid mod IDs and `CfgPatches` entries will be skipped, and appropriate error messages will be logged.

## Example Output

Here is an example of the generated SQF array:

```sqf
[
  ["Core", "Arma 3", "107410"],
  ["A3Data", "", ""],
  ["CUP_Air_Data", "CUP Vehicles", "583496184"],
  ["babe_EM_UI", "Enhanced Movement Rework", "2034363662"]
]
```

## Donations
https://www.buymeacoffee.com/nerexis
Thanks!


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

```

## MIT License

MIT License

Copyright (c) 2024 Damian Winnicki

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
