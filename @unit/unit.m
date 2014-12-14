classdef unit < double
    properties (SetAccess = immutable)
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
        function disp(u)
            F = sprintf('%s [%s] =\n%s',u.name,u.dimensionality,u.value.to_string);
            G = sprintf(['(%s',repmat(', %s',[1,numel(u.aliases)-1]),')\n'],...
                u.aliases{:});
            fprintf('%s%s',F,G)
        end
        function F = subsref(x,s)
            switch s(1).type
                case '.'
                    F = subsref@double(x,s);
                case '()'
                    F = Quantities.unit(subsref(x.name,s(1)),...
                        subsref(x.dimensionality,s(1)),...
                        subsref(x.value,s(1)),...
                        subsref(x.aliases,s(1)));
                    if numel(s)>1
                        F = subsref@double(F,s(2:end));
                    end
            end
        end
        function F = subsasgn(x,s,y)
            switch s(1).type
                case '.'
                    F = subsasgn@double(x,s,y);
                case '()'
                    if numel(s)>1
                        F = subsasgn@double(subsref(x,s(1)),s(2:end),y);
                    else
                        F = Quantities.unit(subsasgn(x.name,s,y.name),...
                            subsasgn(x.dimensionality,s,y.dimensionality),...
                            subsasgn(x.value,s,y.value),...
                            subsasgn(x.aliases,s,y.aliases));
                    end
            end
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
        function F = convert(x,y)
            % CONVERT Convert units.
            if x.is_same_dimensionality(y)
                F = x;
            end
        end
        function F = times(x,y)
            if x.is_same_dimensionality(y)
                F = times(x.value,y);
            end
        end
    end
end
