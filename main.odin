package json

import "core:fmt"
import "core:strings"

Error :: enum{
	NO_ERROR,

	FILE_READ_FAILED,
	NOT_VALID_JSON_FILE,

	TOKEN_LIMIT_EXCEEDED,

	SUBSTRING_FAILED,

	INVALID_VALUE_TYPE,
}
