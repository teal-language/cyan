local record t
   record Report
      tag: string
      parameters: {string:any}
      log_format: string
   end

   type Handler = function({string:any}): Report

   record FormatSpecifier
      key: string
      display_kind: DisplayKind
   end

   enum DisplayKind
      "filename"
   end
end
return t
