classdef prefix
    properties (SetAccess = immutable)
        name
        value
        alias
    end
    methods
        function pre = prefix(name,value)
            pre.name = name;
            pre.value = value;
        end
    end
end