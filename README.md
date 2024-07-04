# index
This extension for the Defold game engine can automatically create an index of all your custom resources before building a game using an editor script, and provides a module for easy access to that index.

![banner](/docs/images/index-banner.jpg)

## Installation
* Copy the folder `index` and the files `.index.txt` and `hooks.editor_script` into your project folder root.
* Add `.index.txt` to your custom resources in `game.project`, separated by a comma from other resources.
* (If you already use a file called `hooks.editor_script`, copy the content from both into one, as you can only use one at the same time.)
* (If you added the extension while the project is already opened, load it first by pressing `Project → Reload Editor Scripts`.)

## Create index
The index will be created automatically by the editor script, and saved in `.index.txt`. All files in your custom resources will be indexed, besides hidden files, indicated by starting with `.`, like `.hidden_file.txt`.

Once the index is created from the editor, it will be bundled with the game, and can be used to access the folder structure, even by target platforms which do not have the file operation access needed to create the index in the first place, like HTML5.

## Read index
While you are free to just open the file `.index.txt` and use it as you wish, this extension provides some functions to make reading the index easier. You can get the index in form of a list, tree, or folder, and also filter the content to only read from a certain folder, or to only get files, or only folders.

To access the index from another script, import the module with
```lua
local index = require "index.index"
```

### Lists
To read the index in form of a list, use `index.get_list([path])`. If no `path` is provided, it will be considered the root, and give you the complete index, which is also the case for the other functions. The list includes paths to every file and every folder included in your custom resources, including subfolders. The list will be a lua table, with integers as keys, and the full paths as values, and sorted alphabetically. You can also get a list of only files, or only folders, by using `index.get_list_files()` or `index.get_list_folders()`.

Example: `index.get_list()`
```lua
{
    1 = "assets/",
    2 = "assets/data.json",
    3 = "assets/images/",
    4 = "assets/images/enemy.png",
    5 = "assets/images/player.png",
    6 = "assets/levels/",
    7 = "assets/levels/1.dat",
    8 = "assets/levels/2.dat",
    9 = "assets/levels/3.dat"
}
```

### Trees
To read the index in form of a tree, use `index.get_tree([path])`. The result is a nested table with the file names as keys, and for files with the full paths as values, and for folders with a tree of that folder as value.

Example: `index.get_tree()`
```lua
{
    assets = {
        data.json = "assets/data.json",
        images = {
            player.png = "assets/images/player.png",
            enemy.png = "assets/images/enemy.png"
        },
        levels = {
            1.dat = "assets/levels/1.dat",
            2.dat = "assets/levels/2.dat",
            3.dat = "assets/levels/3.dat",
        }
    }
}
```

### Folders
To read the index in form of a folder, use `index.get_folder([path])`. The result is a table with the file names as keys, and the full paths as values for both files and folders. Like with lists, you can use `index.get_folder_files()` and `index.get_folder_folders()` to get only files, or only folders. Unlike `get_list()`, the table only contains the content of this folder, and not any deeper levels.

Example: `index.get_folder("assets")`
```lua
{
    data.json = "assets/data.json",
    images = "assets/images/",
    levels = "assets/levels/"
}
```

## Use index
There are also some helper functions to use the index.

To find out if a value from the index is a file or a folder, you can use `index.is_file(path_or_tree)` and `index.is_folder(path_or_tree)`, which returns a boolean. This works for values from lists, trees, and folders. This can be used for example to iterate over the whole index.

Examples:
```lua
local function iterate_list(list)
    for _, v in pairs(list) do
        if index.is_folder(v) then
            print("found folder:  ", v)
        elseif index.is_file(v) then
            print("    found file:", v)
        end
    end
end
iterate_list(index.get_list())
```
```lua
local function iterate_tree(tree)
    for k, v in pairs(tree) do
        if index.is_folder(v) then
            print("found folder:  ", k)
            iterate_tree(v)
        elseif index.is_file(v) then
            print("    found file:", k, "in path:", v)
        end
    end
end
iterate_tree(index.get_tree())
```
```lua
local function iterate_folder(folder)
    for key, value in pairs(folder) do
        if index.is_folder(value) then
            print("character " .. key)
            for name, path in pairs(index.get_folder_files(value)) do
                print("    " .. name .. "  =  " .. path)
            end
        end
    end
end
iterate_folder(index.get_folder_folders("assets/images/characters"))
```

To find out if there is a file indexed on a given path, use `index.is_file_indexed(path)`.

You can also do a deep search for a file name, using `index.find_file(name, [path])`.

## Functions
| Name                                | Description                                                   |
| ----------------------------------- | ------------------------------------------------------------- |
| `index.get_list([path])`            | get index in form of a list                                   |
| `index.get_list_files([path])`      | get index in form of a list, containing only files            |
| `index.get_list_folders([path])`    | get index in form of a list, containing only folders          |
| `index.get_tree([path])`            | get index in form of a tree                                   |
| `index.get_folder([path])`          | get index in form of a folder                                 |
| `index.get_folder_files([path])`    | get index in form of a folder, containing only files          |
| `index.get_folder_folders([path])`  | get index in form of a folder, containing only folders        |
| `index.is_file(path_or_tree)`       | returns true if given path or tree is a file                  |
| `index.is_folder(path_or_tree)`     | returns true if given path or tree is a folder                |
| `index.find_file(name, [path])`     | searches for file with given name, and returns path if found  |
| `index.create()`                    | creates index file (not necessary to call manually)           |
