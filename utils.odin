package json

import "core:strings"
import "core:strconv"
import "core:fmt"

has_file_suffix :: proc(filename: string, suffix: cstring) -> bool{
	filename := string(filename)
	suffix := string(suffix)

	return strings.has_suffix(filename, suffix)
}

// just to clean up the json a little
clean_file_data :: proc(data: File_data) -> string{
	it := string(data)

	output: string

  // Remove line breaks
  output, _ = strings.replace(it, "\r\n", "", -1)
  output, _ = strings.replace(output, "\n", "", -1)
	output, _ = strings.replace(output, "\r", "", -1)

	return output
}

//removes all tabs and spaces from a string
remove_whitespace :: proc(str: string) -> string{
	output := str

	output, _ = strings.replace(output, " ", "", -1)
	output, _ = strings.replace(output, "	", "", -1)

	return output
}

NUMBERS : [12]u8: {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '.'}

// checks if char is a number or a . or -
char_is_number :: proc(char: u8) -> bool{
	for num in NUMBERS{
		if char == num do return true
	}

	return false
}

// checks if a string is a number
string_is_number :: proc(value: string) -> bool{
	for _, i in value{
		if !char_is_number(value[i]) do return false
	}

	return true
}

VALID_TOKENS : [6]u8: {'{', '}', '[', ']', ',', ':'}

// checks if char is a number or a . or -
char_is_token :: proc(char: u8) -> bool{
	for t in VALID_TOKENS{
		if char == t do return true
	}

	return false
}

number_value_is_float :: proc(s: string) -> bool{
	for char in s{
		if char == '.' do return true
	}

	return false
}

// takes in a file and returns a Value
parse_file :: proc(filepath: string) -> (Value, Error){

	// Load the file and get the data
	file_data, load_err := load_file(filepath)
	if load_err != .NO_ERROR do return nil, load_err
	defer delete(file_data) // Free the file data after parse is done

	// Tokenize file data
	tokens, tokenizer_err := tokenize_json_data(file_data)
	if tokenizer_err != .NO_ERROR do return nil, tokenizer_err

	// Parse data
	parsed_data, parse_err := parse(tokens)
	if parse_err != .NO_ERROR do return nil, parse_err

	return parsed_data, .NO_ERROR
}

//Destroy a value union
destroy_value :: proc(value: ^Value) -> Error{

	#partial switch v in value {
	case Object:
		for _, &second_value in value.(Object){
			destroy_value(&second_value)
		}
		err := delete_map(value.(Object))
		if err != .None do return .ERROR_DELETING_VALUE
	case Array:
		for &second_value in value.(Array){
			destroy_value(&second_value)
		}
		err := delete_dynamic_array(value.(Array))
		if err != .None do return .ERROR_DELETING_VALUE
	}

	return .NO_ERROR
}
