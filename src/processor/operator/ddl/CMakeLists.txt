add_library(kuzu_processor_operator_ddl
        OBJECT
        alter.cpp
        create_table.cpp
        create_type.cpp
        drop.cpp
        create_sequence.cpp)

set(ALL_OBJECT_FILES
        ${ALL_OBJECT_FILES} $<TARGET_OBJECTS:kuzu_processor_operator_ddl>
        PARENT_SCOPE)
