classdef prefix < double
    properties (SetAccess = immutable)
        name
        value = 1
        aliases = {}
    end
    methods
        function pre = prefix(name,value,aliases)
            % default value
            if nargin<2
                value = 1;
            end
            % value must be either numeric or a dimension class
            validateattributes(value,{'numeric'},...
                {'scalar'},'prefix','value',2)
            pre = pre@double(value); % required for subclass of double
            pre.name = name;
            pre.value = value;
            % aliases
            if nargin>2 && ~isempty(aliases)
                validateattributes(aliases,{'cell'},{'vector'},...
                    'unit','aliases',4)
                assert(iscellstr(aliases),'unit:aliases',...
                    'Aliases must be a cell string.')
                pre.aliases = aliases;
            end
        end
        function F = times(pre,u)
            validateattributes(u,{'Quantities.unit'},{'scalar'},'times','u',2)
            assert(u.value==1,'prefix:times',...
                'Prefixes can only be combined with base units.')
            F = Quantities.unit([pre.name,u.name],u.dimensionality,...
                pre.value.*u);
        end
        function F = mtimes(pre,u)
            F = pre.*u;
        end
    end
end