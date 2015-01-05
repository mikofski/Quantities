classdef constant < Quantities.quantity
    properties (SetAccess=immutable)
        name
        value
    end
    methods
        function const = constant(name,value,units)
            if nargin<3
                units = Quantities.unit.DIMENSIONLESS;
            end
            validateattributes(name,{'char'},{'row'},...
                'constant','name',1)
            validateattributes(value,{'numeric'},{'real','finite'},...
                'constant','value',2)
            validateattributes(units,{'Quantities.unit'},{'scalar'},...
                'constant','units',3)
            const = const@Quantities.quantity(value,'units',units);
            const.name = name;
            const.value = value;
        end
        function F = char(const)
            F = sprintf('\t%s (constant) =\n%s',const.name,...
                char@Quantities.quantity(const));
        end 
    end
end
