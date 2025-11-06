package json

import "core:os"
import "core:strings"
import "core:fmt"

File_data :: string

load_file :: proc(filepath: string) -> (file_data: File_data, err: Error){
	if !has_file_suffix(filepath, "json") do return "", .NOT_VALID_JSON_FILE

	data, ok := os.read_entire_file(filepath, context.allocator)
	// Delete the data slice
	defer delete(data)
	
	if !ok {
		// could not read file

		return "", .FILE_READ_FAILED 
	}


	output_data := strings.clone(File_data(data))
	
	return output_data, .NO_ERROR
}
