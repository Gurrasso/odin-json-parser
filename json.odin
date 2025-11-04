#+feature dynamic-literals
package json

import "core:strconv"
import "core:strings"
import "core:fmt"

// =======================
//    		TOKENIZER
// =======================


// A tokens data
Token :: struct{
	type: Token_type,
	value: string
}

Tokens :: [MAX_TOKENS]Token

// The type of a token
Token_type :: enum{
	NIL,

	OPEN_CURLY_BRACKET,
	CLOSED_CURLY_BRACKET,

	OPEN_SQUARE_BRACKET,
	CLOSED_SQUARE_BRACKET,

	COMMA,

	KEY,
	STRING_VALUE,
	NUMBER_VALUE,
	BOOL_VALUE,
	NULL_VALUE,
}

//Max amount of tokens in the tokenize_json_data proc
MAX_TOKENS :: 1024

// Takes in json data and tokenizes it line by line
tokenize_json_data :: proc(data: File_data) -> (Tokens, Error){
	string_data := clean_file_data(data)
	no_whitespace_string_data := remove_whitespace(string_data)
	
	tokens: Tokens
	tokens_cursor: int

	if len(no_whitespace_string_data) == 0 do return tokens, .NO_DATA_TO_TOKENIZE
	else if ODIN_DEBUG do fmt.println("Cleaned json data:", no_whitespace_string_data)

	for i := 0; i <len(string_data); i+=1{
		
		//skip tabs and spaces
		if string_data[i] == ' ' || string_data[i] == '	' do continue
		
		value: Token
		err: Error

		value, err = tokenize(string_data, &i)

		if err != .NO_ERROR do return tokens, err

		err = append_to_tokens(&tokens, &tokens_cursor, value)

		if err != .NO_ERROR do return tokens, err
	}

	if ODIN_DEBUG && len(string_data) > 0{
		fmt.println("//    Printing tokens    //")
		for i in 0..<tokens_cursor{
			fmt.println(tokens[i])
		}
	}

	// TODO: maybe validate the tokens like checking that we have the same number of open as closed brackets and that all keys have a value ect.

	return tokens, .NO_ERROR
}

//Creates a token from a rune
tokenize :: proc(data: string, i: ^int) -> (Token, Error){

	char := data[i^]

	token: Token
	switch char{
	case '{':
		token.type = .OPEN_CURLY_BRACKET
		token.value = "{"
	case '}':
		token.type = .CLOSED_CURLY_BRACKET
		token.value = "}"
	case '[':
		token.type = .OPEN_SQUARE_BRACKET
		token.value = "["
	case ']':
		token.type = .CLOSED_SQUARE_BRACKET
		token.value = "]"
	case ',':
		token.type = .COMMA
		token.value = ","
	case:
		if char == '"' { 					// value is a string
			for j in i^+1..<len(data){
				//check if we reached end of value
				if data[j] == '"'{
					// Get the data
					value, ok := strings.substring(data, i^+1, j)
					if !ok do return token, .SUBSTRING_FAILED
						
					token.value = value

					if data[j+1] == ':'{
						token.type = .KEY

						//this skips the semi-colon
						i^ = j+1
					}else {
						token.type = .STRING_VALUE

						// set the index to be after the value
						i^ = j
					}

					break
				}
			}

		}else{  				// value is not a string
			for j in i^+1..<len(data){
				//check if we reached end of value
				if char_is_token(data[j]){
					value, ok := strings.substring(data, i^, j)
					if !ok do return token, .SUBSTRING_FAILED

					token.value = value

					// check for the type of the value
					if string_is_number(value) do token.type = .NUMBER_VALUE
					else if value == "null" do token.type = .NULL_VALUE
					else if value == "true" || value == "false" do token.type = .BOOL_VALUE
					else {
						fmt.println("Error at value:", value)
						return token, .INVALID_VALUE_TYPE
					}

					// set the index to be after the value
					i^ = j-1

					break
				}
			}
		}
	}

	return token, .NO_ERROR
}


// =====================
//    		PARSER
// =====================

//Type definitions
Integer :: i64
Float   :: f64
Boolean :: bool
String  :: string
Array   :: distinct [dynamic]Value
Object  :: distinct map[string]Value

//Value union that uses maps for objects
Value :: union {
	Integer,
	Float,
	Boolean,
	String,
	Array,
	Object,
}

// Initiates the recursive tokenizing
parse :: proc(tokens: Tokens) -> (Value, Error){
	value, err := parse_token(0, tokens)

	if err != .NO_ERROR do return value, err

	if ODIN_DEBUG {
		fmt.println("// PRINTING PARSED DATA //")
		fmt.println(value)
	}

	return value, .NO_ERROR
}

//Recursivly goes through the list of tokens converting them all into a singe value struct
parse_token :: proc(index: int, tokens: Tokens) -> (Value, Error){
	
	token := tokens[index]
	value: Value
	

	switch token.type{
	case .STRING_VALUE:
		value = token.value
	case .NUMBER_VALUE: //Convert number to a float or and int depending on if it has a . in it

		ok: bool
		
		if number_value_is_float(token.value) do value, ok = strconv.parse_f64(token.value)
		else do value, ok = strconv.parse_i64(token.value)

		if !ok do return value, .STRING_TO_NUMBER_CONVERSION_FAILED

	case .BOOL_VALUE: //Converts the string into a bool
		ok: bool

		value, ok = strconv.parse_bool(token.value)

		if !ok do return value, .STRING_TO_BOOL_CONVERSION_FAILED

	case .NULL_VALUE:
		value = nil
	
	case .OPEN_CURLY_BRACKET: // Goes through counting brackets and if we reached the end bracket exits. It will also look for ids to also parse.
		bracket_count: int = 1

		object := make(Object)

		for j in index+1..<len(tokens){

			t := tokens[j]

			if t.type == .OPEN_CURLY_BRACKET{
				bracket_count += 1
			}else if t.type == .CLOSED_CURLY_BRACKET{
				bracket_count -= 1
			}

			if bracket_count == 0{
				break
			}else if bracket_count == 1{
				if t.type == .KEY{
					err: Error

					if t.value in object{
						//free the memory on error
						for _, &second_value in object{
							destroy_value(&second_value)
						}
						delete(object)

						return value, .KEY_ALREADY_PART_OF_MAP
					}

					object[t.value], err = parse_token(j+1, tokens)
					if err != .NO_ERROR {
						//free the memory on error
						for _, &second_value in object{
							destroy_value(&second_value)
						}
						delete(object)

						return value, err
					}
				}
			}
		}

		value = object

	case .OPEN_SQUARE_BRACKET: // Counts the brackets and looks for values to parse and add to the array
		bracket_count: int = 1

		array: Array

		for j in index+1..<len(tokens){

			t := tokens[j]

			if t.type == .OPEN_SQUARE_BRACKET{
				bracket_count += 1
			}else if t.type == .CLOSED_SQUARE_BRACKET{
				bracket_count -= 1
			}


			if bracket_count == 0{
				break
			}else if bracket_count == 1{
				if t.type == .OPEN_SQUARE_BRACKET || t.type == .OPEN_SQUARE_BRACKET || t.type == .STRING_VALUE || t.type == .NUMBER_VALUE || t.type == .BOOL_VALUE || t.type == .NULL_VALUE{
					
					v, err := parse_token(j, tokens)

					if err != .NO_ERROR {
						//free the memory on error
						for &second_value in array{
							destroy_value(&second_value)
						}
						delete(array)

						return value, err
					}

					append(&array, v)
				}
			}
		}

		value = array
	case .CLOSED_CURLY_BRACKET: // I dont think we should reach these but if we do we just skip to the next value
		err: Error

		value, err = parse_token(index+1, tokens)
		if err != .NO_ERROR do return value, err
	case .CLOSED_SQUARE_BRACKET:
		err: Error

		value, err = parse_token(index+1, tokens)
		if err != .NO_ERROR do return value, err
	case.COMMA:
		err: Error

		value, err = parse_token(index+1, tokens)
		if err != .NO_ERROR do return value, err
	case .KEY:
		return value, .KEY_NOT_PART_OF_MAP

	case .NIL:
		return value, .FAILED_PARSE_NIL_TOKEN_TYPE
	case:
		return value, .FAILED_PARSE_INVALID_TOKEN_TYPE
	}

	return value, .NO_ERROR
}

// ======================
//    STRINGIFY VALUE
// ======================

// takes in the value and gives back a tokens array
tokenize_value :: proc(value: Value) -> (Tokens, Error){
	return_tokens: Tokens
	tokens_cursor: int
	
	tokens, err := get_tokens_from_value(value)
	if err != .NO_ERROR do return return_tokens, err

	append_to_tokens_slice(&return_tokens, &tokens_cursor, tokens[:])

	delete_dynamic_array(tokens)

	return return_tokens, .NO_ERROR
}

// tokenizes a value recursivly and returns a dynamic array
get_tokens_from_value :: proc(value: Value) -> ([dynamic]Token, Error){
	tokens: [dynamic]Token

	switch v in value{
	case String:
		append(&tokens, Token{value = value.(String), type = .STRING_VALUE})
	case Integer:
		buf: [32]byte
		string_value := strconv.write_int(buf[:], i64(value.(Integer)), 10)
		append(&tokens, Token{value = strings.clone(string_value), type = .NUMBER_VALUE})
	case Float:
		buf: [32]byte
		string_value := strconv.write_float(buf[:], f64(value.(Float)), 'f', get_float_percision(value.(Float)), 64)
		append(&tokens, Token{value = strings.clone(string_value), type = .NUMBER_VALUE})
	case Boolean:
		buf: [32]byte
		string_value := strconv.write_bool(buf[:], value.(Boolean))
		append(&tokens, Token{value = strings.clone(string_value), type = .BOOL_VALUE})
	case Array:
		append(&tokens, Token{value = "[", type = .OPEN_SQUARE_BRACKET})
		for elem, iterator in value.(Array) {
			elem_tokens, err := get_tokens_from_value(elem)
			if err != .NO_ERROR do return tokens, err

			for token in elem_tokens{
				append(&tokens, token)
			}
			if iterator != len(value.(Array))-1 do append(&tokens, Token{value = ",", type = .COMMA})
			delete(elem_tokens)
		}
		append(&tokens, Token{value = "]", type = .CLOSED_SQUARE_BRACKET})
	case Object:
		append(&tokens, Token{value = "{", type = .OPEN_CURLY_BRACKET})
		iterator: int
		for key, obj in value.(Object) {
			obj_tokens, err := get_tokens_from_value(obj)
			if err != .NO_ERROR do return tokens, err
			append(&tokens, Token{value = key, type = .KEY})

			for token in obj_tokens{
				append(&tokens, token)
			}
			
			if iterator != len(value.(Object))-1 do append(&tokens, Token{value = ",", type = .COMMA})

			delete(obj_tokens)
			iterator += 1
		}
		append(&tokens, Token{value = "}", type = .CLOSED_CURLY_BRACKET})
	case nil:
		append(&tokens, Token{value = "null", type = .NULL_VALUE})
	case:
		return tokens, .CANNOT_TOKENIZE_VALUE_BECAUSE_OF_TYPE
	}


	return tokens, .NO_ERROR
}

// takes in tokens and turns it into a string of json
stringify_tokens :: proc(tokens: Tokens) -> (string, Error){
	output_strings: [dynamic]string
	output_string: string

	defer delete(output_strings) // delete the dynamic array when we are done

	// Loop through our tokens
	for token in tokens{
		if token.type == .NIL do break // break if token type is nil

		// add the string we get to an array so we can join the array into a string later
		append_string, err := stringify_token(token)
		if err != .NO_ERROR do return output_string, err

		append(&output_strings, append_string)
	}

	output_string = strings.join(output_strings[:], "") //Smush all the strings into one

	return output_string, .NO_ERROR
}

// takes in a token and turns it into a string that can be part of a string of json
stringify_token :: proc(token: Token) -> (string, Error){
	output_string: string = token.value

	// check for nil type
	if token.type == nil do return output_string, .CANNOT_STRINGIFY_TOKEN_BECAUSE_OF_TYPE

	// go through the token types that aren't as straight forward
	#partial switch token.type{
	case .NIL: //should never be reached
		return output_string, .CANNOT_STRINGIFY_TOKEN_BECAUSE_OF_TYPE 
	
	case .KEY:
		output_string = strings.join({"\"", output_string, "\"", ":"}, "")

	case .STRING_VALUE:
		output_string = strings.join({"\"", output_string, "\""}, "")
	}

	return output_string, .NO_ERROR
}

