	-- View --
    CREATE [ OR REPLACE ] [ TEMP | TEMPORARY 临时视图] [ RECURSIVE ] <VIEW name 视图名> [ ( column_name指定列名 [, ...] ) ]
    [ WITH ( view_option_name [= view_option_value] [, ... ] ) ]
    AS query --这是必须写的
    [ WITH [ CASCADED | LOCAL ] CHECK OPTION ]

