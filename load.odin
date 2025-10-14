package json

import "core:os"
import "core:strings"
import "core:fmt"

File_data :: []byte

load_file :: proc(filepath: string) -> (file_data: File_data, err: Error){
	if !has_file_suffix(filepath, "json") do return nil, .NOT_VALID_JSON_FILE

	data, ok := os.read_entire_file(filepath, context.allocator)
	
	if !ok {
		// could not read file

		return nil, .FILE_READ_FAILED 
	}
	
	return data, .NO_ERROR
}
