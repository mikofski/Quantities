classdef dimension
    properties
        name % name of dimension
        value = 1 % value of dimension in terms of other dimensions
        dimensions = {} % dimensions
        degrees % power of each dimension
    end
    methods
        function dim = dimension(name,value)
            dim.name = name;
            dim.value = value;
            dim.dimensions, dim.degrees = Quantities.unit.parse_name(value);
        end
    end
end