classdef constant < Quantities.quantity
    properties (SetAccess=immutable)
        name
        value
        aliases
    end
    properties (Constant)
        PI = Quantities.constant('pi',Quantities.quantity(pi))
    end
    methods
        function const = constant(name,value,aliases)
            validateattributes(name,{'char'},{'row'},...
                'constant','name',1)
            validateattributes(value,{'Quantities.quantity'},{'scalar'},...
                'constant','value',2)
            const = const@Quantities.quantity(value.average,value.stdev,value.units);
            const.name = name;
            const.value = value;
            % parse aliases
            if nargin>2 && ~isempty(aliases)
                validateattributes(aliases,{'cell'},{'vector'},'unit','aliases',4)
                assert(iscellstr(aliases),'unit:aliases',...
                    'Aliases must be a cell string.')
                const.aliases = aliases;
            end
        end
        function F = char(const)
            if ~isempty(const.aliases)
                G = sprintf(['\t(%s',repmat(', %s',[1,numel(const.aliases)-1]),')\n'],...
                    const.aliases{:});
            else
                G = '';
            end
            F = sprintf('\t%s (constant) =\n%s%s',const.name,...
                char@Quantities.quantity(const),G);
        end 
    end
end
