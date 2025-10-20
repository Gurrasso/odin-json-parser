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

// The type of a token
Token_type :: enum{
	NIL,

	OPEN_CURLY_BRACKET,
	CLOSED_CURLY_BRACKET,

	OPEN_SQUARE_BRACKET,
	CLOSED_SQUARE_BRACKET,

	COMMA,

	ID,
	STRING_VALUE,
	NUMBER_VALUE,
	BOOL_VALUE,
	NULL_VALUE,
}

//Max amount of tokens in the tokenize_json_data proc
MAX_TOKENS :: 1024

// Takes in json data and tokenizes it line by line
tokenize_json_data :: proc(data: File_data) -> ([MAX_TOKENS]Token, Error){
	string_data := clean_file_data(data)

	if ODIN_DEBUG{
		if len(string_data) == 0 do fmt.println("OBS! json data given is empty")
		else do fmt.println("Cleaned json data: ", string_data)
	}

	tokens: [MAX_TOKENS]Token
	tokens_cursor: int

	for i := 0; i <len(string_data); i+=1{
		if tokens_cursor >= len(tokens)-1{
			// We have exceeded the max amount of tokens
			return tokens, .TOKEN_LIMIT_EXCEEDED
		}
		
		value: Token
		err: Error

		value, err = tokenize(string_data, &i)

		if err != .NO_ERROR do return tokens, err

		token := &tokens[tokens_cursor%len(tokens)]
		token^ = value
		tokens_cursor += 1
	}

	if ODIN_DEBUG && len(string_data) > 0{
		fmt.println("//    Printing tokens    //")
		for i in 0..<tokens_cursor{
			fmt.println(tokens[i])
		}
	}

	// TODO: maybe validate the tokens like checking that we have the same number of open as closed brackets and that all ids have a value ect.

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
						token.type = .ID

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

Value :: union{
	int,
	f32,
	bool,
	string,
	[]Value, 
	map[string]Value,
}

// Initiates the recursive tokenizing
parse :: proc(tokens: [MAX_TOKENS]Token) -> (Value, Error){
	value, err := parse_token(0, tokens)

	if err != .NO_ERROR do return value, err

	if ODIN_DEBUG {
		fmt.println("// PRINTING PARSED DATA //\n", value)
	}

	return value, .NO_ERROR
}

//Recursivly goes through the list of tokens converting them all into a singe value struct
parse_token :: proc(index: int, tokens: [MAX_TOKENS]Token) -> (Value, Error){
	
	token := tokens[index]
	value: Value
	

	switch token.type{
	case .STRING_VALUE:
		value = token.value
	case .NUMBER_VALUE:

		ok: bool
		
		if number_value_is_float(token.value) do value, ok = strconv.parse_f32(token.value)
		else do value, ok = strconv.parse_int(token.value)

		if !ok do return value, .STRING_TO_NUMBER_CONVERSION_FAILED

	case .BOOL_VALUE:
		ok: bool

		value, ok = strconv.parse_bool(token.value)

		if !ok do return value, .STRING_TO_BOOL_CONVERSION_FAILED

	case .NULL_VALUE:
		value = nil
	
	case .OPEN_CURLY_BRACKET:
		bracket_count: int = 1

		object := make(map[string]Value)

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
				if t.type == .ID{
					err: Error

					object[t.value], err = parse_token(j+1, tokens)
					if err != .NO_ERROR do return value, err
				}
			}
		}

		value = object

	case .OPEN_SQUARE_BRACKET:
		bracket_count: int = 1

		array: [dynamic]Value 

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

					if err != .NO_ERROR do return value, err

					append(&array, v)
				}
			}
		}

		value = array[:]
	case .CLOSED_CURLY_BRACKET:
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
	case .ID:
		return value, .ID_NOT_PART_OF_MAP

	case .NIL:
		return value, .FAILED_PARSE_NIL_TOKEN_TYPE
	case:
		return value, .FAILED_PARSE_INVALID_TOKEN_TYPE
	}

	return value, .NO_ERROR
}
