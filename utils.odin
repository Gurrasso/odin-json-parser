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

	// Remove tabs and spaces
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
