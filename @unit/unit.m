classdef unit < double
    properties
        name
        dimensionality % dimensionality
        value % SI equivalent value
        aliases
    end
    methods
        function u = unit(name,dimensionality,value,aliases)
            u = u@double(value);
            u.name = name;
            u.dimensionality = dimensionality;
            u.value = value;
            u.aliases = aliases;
        end
        function F = subsasgn(x,s,y)
            F = Quantities.unit(subsasgn(x.name,s,y.name),...
                subsasgn(x.dimensionality,s,y.dimensionality),...
                subsasgn(x.value,s,y.value),...
                subsasgn(x.aliases,s,y.aliases));
        end
        function F = horzcat(varargin)
            nF = numel(varargin);
            F = Quantities.unit.empty(0,nF);
            for n = 1:nF
                F(n) = varargin{n};
            end
        end
        function F = is_same_dimensionality(u,v)
            if isscalar(u) && isscalar(v)
                F = strcmp(u.dimensionality,v.dimensionality);
            elseif isscalaar(u)
                vdims = cellfun(@(x)x.dimensionality,v,'UniformOutput',false);
                F = strcmp(u.dimensionality,vdims);
            end
        end
    end
end
