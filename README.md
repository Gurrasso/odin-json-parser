# ODIN JSON PARSER

A parser and stringifier for json for the odin language.

## Description

This is a simple parser and stringifier for odin. This can be used to write json to a file or to read json from a file. It's still a work in progress but the base functionality is there. Just so you know there is already a json parser inside of "core:encoding/json".

The code is probably full of bugs, bad code and possibly memory leaks but it works. It also isn't very strict on your json syntax.

## Getting Started

### Dependencies

* All you need to use this is the odin compiler along with the standard odin packages(core, base, ect)

### Installing

* To download just clone this repo and put it in your project or in your odin shared packages folder

### Using the package

* There are some prints and such throughout the package. This is for debugging and most of them will only run when the "-debug" flag is used.
```
odin build path_to_code -debug
```

* There is also a hard limit on tokens. Any token array has a max size but this can be changed by changing the MAX_TOKENS constant in the code
```odin
// In the json.odin file we find this
MAX_TOKENS :: 1024
```


* Lets take a small look at the error handeling
```odin
// Errors are an enum and any error will be returned through the procedures like this.

foo, err := get_data(bar)

// To see what the error does you can look at where it gets called or i might implement some sort of error check procedure in the future
if err != .NO_ERROR do return foo, err
```

#### Basic way to use the package

#####   Parsing a json file

* Lets look at how to use the parser using the parse_file proc in the utils file. This is the simplest way to parse a file.
```odin
package main

import "shared:odin-json-parser"

main :: proc(){
    // This will return a Value which we will look more at later
    parsed_data, err := json.parse_file("path_to_file.json")

    // Once we are done with our parsed data it is a good idea to free it from memory by calling the destroy_value proc
    // Here we just panic if we fail to destroy the value
    defer if json.destroy_value(&parsed_data) != .NO_ERROR do panic("Failed to destroy value")

    // Handle an error if we get one 
    if err != .NO_ERROR do handle_error()
}

```

* All parsed data gets returned as a Value union
```odin
// The value union looks like this
Value :: union {
	Integer,
	Float,
	Boolean,
	String,
	Array,
	Object,
}

// And all the types look like this
Integer :: i64
Float   :: f64
Boolean :: bool
String  :: string
Array   :: distinct [dynamic]Value    // The Array and Object types contain Value which means we can have values in values in values just like with javascript objects
Object  :: distinct map[string]Value  // Since odin doesn't have any javascript objects we use maps with strings as keys
```
Lets say we have some json that looks like this:
```json
{
    "foo": {
        "bar": [139123, 1201]
    }
}
```
We can parse this json into a Value and get our data
```odin
data, _ := json.parse_file("path_to_file.json")

// To get bar we can do look through the union
// We can use unions type assertions to look into the Value and get our data
bar := data.(json.Object)["foo"].(Object)["bar"]
```

#####   Stringifying a Value

* When we want to stringify a Value we can use the stringify_value proc from the utils file
```odin
#+feature dynamic-literals
package main

import "shared:odin-json-parser"
import "core:fmt"

main :: proc(){
    // We can have some data which we want to stringify
    value: json.Value = json.Object{"foo" = json.Object{"bar" = json.Array{23120, 123823}}}

    // Remember to free your memory
    defer if json.destroy_value(&value) != .NO_ERROR do panic("Failed to destroy value")

    json_string, err := json.stringify_value(json_data)

    // Handle an error if we get one 
    if err != .NO_ERROR do handle_error()

    // This string can be used to write to a file, or we can print it to see what the json would look like
    fmt.println(json_string)
}
```

#### More in depth usage and explanations

#####   Parsing a json file

* You can have a look through the parse_file proc and see how it works but here are the basics:
```odin
parse_file :: proc(filepath: string) -> (Value, Error){

    // We first load the file and get the data
    // If we already have a string with json we can skip this step and just go to tokenizing and parsing
    file_data, load_err := load_file(filepath)
    if load_err != .NO_ERROR do return nil, load_err

    // And also delete the file data when we dont need it
    defer delete(file_data) 

    // Then we tokenize the file data
    // It takes in File_data and turns it into a Tokens array
    tokens, tokenizer_err := tokenize_json_data(file_data)
    if tokenizer_err != .NO_ERROR do return nil, tokenizer_err

    // It then takes the Tokens array and turns it into a Value
    parsed_data, parse_err := parse(tokens)
    if parse_err != .NO_ERROR do return nil, parse_err

    return parsed_data, .NO_ERROR
}
```

*   After we are done with the Value we can destroy it using the destroy_value proc.
    The destroy_value proc takes in the pointer to a value and recursivly goes through and deletes everything.


#####   Stringifying a Value

* The stringify Value proc is quite simple, if you want you can have a look at it.

* When we have stringified the Value we might want to write it to a file:
```odin
package main

import "shared:odin-json-parser"
import "core:os"
import "core:fmt"

main :: proc(){
    value: json.Value = foo
    defer json.destroy_value(value)

    json_string, _ := json.stringify_value(value)

    file := "path_to_file.json"

    f, err := os.open(file, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
    if err != nil {
		handle_error()
    }
    defer os.close(f)

    fmt.fprintln(f, json_string)
}
```

## Help

It's just odin code, there shouldn't be any major problems apart from the code being bad. If you have a problem maybe try checking your odin version and if it's outdated, update it.

To check the version run this in your command prompt:
```
odin version
```

## License

Distributed under the MIT License.

## TODO

* Add a proc for getting info about errors from the Error enum

    Could look like this:
    ```odin
    package main

    import "shared:odin-json-parser"
    import "core:fmt"

    main :: proc(){
        data, err := json.random_proc()

        if err != .NO_ERROR {
            // Get a string describing the error and what might cause it
            fmt.println(json.get_error_data(err))

            return
        }
    }
    ```

* More strict json syntax checks

* Better formatted json when stringifying

    Have the option to get nice indented json back when stringifying. 
    Good for readability


* Maybe remove the limit on tokens

* Continue to update the readme
