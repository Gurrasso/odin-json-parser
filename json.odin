package json

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


