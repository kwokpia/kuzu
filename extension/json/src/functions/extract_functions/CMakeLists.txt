add_library(kuzu_json_extract_functions
        OBJECT
        json_extract.cpp)

set(JSON_EXTENSION_OBJECT_FILES
        ${JSON_EXTENSION_OBJECT_FILES} $<TARGET_OBJECTS:kuzu_json_extract_functions>
        PARENT_SCOPE)
