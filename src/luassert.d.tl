local record ArrayAssert
   has_holes:function(integer)
   has_no_holes:function()
end

local record SpyAssert
   was_called:function(integer)
   was_not_called:function(integer)

   was_called_with:function(...:any)
   was_not_called_with:function(...:any)

   was_returned_with:function(...:any)
   was_not_returned_with:function(...:any)

   was_called_at_least:function(integer)
   was_called_at_most:function(integer)
   was_called_more_than:function(integer)
   was_called_less_than:function(integer)

   was_not_called_at_least:function(integer)
   was_not_called_at_most:function(integer)
   was_not_called_more_than:function(integer)
   was_not_called_less_than:function(integer)

   called:function(integer)
   not_called:function()

   called_with:function(...:any)
   not_called_with:function(...:any)

   returned_with:function(...:any)
   not_returned_with:function(...:any)

   called_at_least:function(integer)
   called_at_most:function(integer)
   called_more_than:function(integer)
   called_less_than:function(integer)
end

-- We use asserts instead of assert here to avoid tl warning
local record asserts
   -- True / false
   is_not_true:function(any, ?string):any, string
   is_true:function(any, ?string):any, string

   is_not_false:function(any, ?string):any, string
   is_false:function(any, ?string):any, string

   is_not_truthy:function(any, ?string):any, string
   is_truthy:function(any, ?string):any, string

   truthy:function(any, ?string):any, string
   not_truthy:function(any, ?string):any, string

   is_not_falsy:function(any, ?string):any, string
   is_falsy:function(any, ?string):any, string

   falsy:function(any, ?string):any, string
   not_falsy:function(any, ?string):any, string

   -- Same-ness
   same:function(any, any, ?string):any, any, string

   is_same:function(any, any, ?string):any, any, string
   is_not_same:function(any, any, ?string):any, any, string

   are_same:function(any, any, ?string):any, any, string
   are_not_same:function(any, any, ?string):any, any, string

   -- Equality
   are_not_equal:function(any, any, ?string):any, any, string
   are_not_equals:function(any, any, ?string):any, any, string

   is_not_equal:function(any, any, ?string):any, any, string
   is_not_equals:function(any, any, ?string):any, any, string

   equal:function(any, any, ?string):any, any, string
   equals:function(any, any, ?string):any, any, string

   not_equals:function(any, any, ?string):any, any, string
   not_equal:function(any, any, ?string):any, any, string

   equals_not:function(any, any, ?string):any, any, string
   equal_not:function(any, any, ?string):any, any, string

   is_equal:function(any, any, ?string):any, any, string
   is_equals:function(any, any, ?string):any, any, string

   are_equal:function(any, any, ?string):any, any, string
   are_equals:function(any, any, ?string):any, any, string

   -- Nearness
   is_near:function(number, number, number, ?string):number, number, number, string
   is_not_near:function(number, number, number, ?string):number, number, number, string

   -- Uniqueness
   is_unique:function({any}, ?string):{any}, string
   is_not_unique:function({any}, ?string):{any}, string

   are_unique:function({any}, ?string):{any}, string
   are_not_unique:function({any}, ?string):{any}, string

   -- Errors function
   is_error:function(function(), any, ?string):{any}
   error:function(function(), any, ?string):{any}
   errors:function(function(), any, ?string):{any}

   no_errors:function(function(), any, ?string):{any}

   has_no_errors:function(function(), any, ?string):{any}
   has_no_error:function(function(), any, ?string):{any}

   has_error:function(function(), any, ?string):{any}
   has_errors:function(function(), any, ?string):{any}

   record Callable
      metamethod __call: function(self: Callable)
   end

   -- Errors Callable
   is_error:function(Callable, any, ?string):{any}
   error:function(Callable, any, ?string):{any}
   errors:function(Callable, any, ?string):{any}

   no_errors:function(Callable, any, ?string):{any}

   has_no_errors:function(Callable, any, ?string):{any}
   has_no_error:function(Callable, any, ?string):{any}

   has_error:function(Callable, any, ?string):{any}
   has_errors:function(Callable, any, ?string):{any}

   -- Errors matches
   does_error_match:function(function(), string, ?string)
   matches_error:function(function(), string, ?string)
   has_no_error_match:function(function(), string, ?string)
   does_not_match_error:function(function(), string, ?string)

   error_matches:function(function(), string, ?string):{any}
   no_error_matches:function(function(), string, ?string):{any}

   -- Errors matches callable
   does_error_match:function(Callable, string, ?string)
   matches_error:function(Callable, string, ?string)
   has_no_error_match:function(Callable, string, ?string)
   does_not_match_error:function(Callable, string, ?string)

   error_matches:function(Callable, string, ?string):{any}
   no_error_matches:function(Callable, string, ?string):{any}

   -- matches
   match:function(string, string, ?string) -- TODO: upstream this to teal types
   matches:function(string, string, ?string)

   not_match: function(string, string, ?string) -- TODO: upstream this to teal types

   has_match:function(string, string, ?string):{string}
   has_no_match:function(string, string, ?string):{string}

   -- type checking
   is_boolean:function(any, ?string):any, string
   is_not_boolean:function(any, ?string):any, string

   is_number:function(any, ?string):any, string
   is_not_number:function(any, ?string):any, string

   is_string:function(any, ?string):any, string
   is_not_string:function(any, ?string):any, string

   is_table:function(any, ?string):any, string
   is_not_table:function(any, ?string):any, string

   is_function:function(any, ?string):any, string
   is_not_function:function(any, ?string):any, string

   is_userdata:function(any, ?string):any, string
   is_not_userdata:function(any, ?string):any, string

   is_thread:function(any, ?string):any, string
   is_not_thread:function(any, ?string):any, string

   is_nil:function(any, ?string):any, string
   is_not_nil:function(any, ?string):any, string

   -- misc
   set_parameter:function(self:asserts, string, integer)

   returned_arguments:function(...:any)
   not_returned_arguments:function(...:any)

   has_holes:function({any})
   has_no_holes:function({any})

   array:function({any}):ArrayAssert

   spy:function(any):SpyAssert
   stub:function(any):SpyAssert

   get_level:function(self:asserts, any)
   level:function(self:asserts, integer)

   has_property:function(any, string)
end

return asserts
