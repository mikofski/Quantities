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
            validateattributes(name,{'char'},{'row'},'dimension','name',1)
            % value must be either numeric
            % can't filter real/finite without allowing index/assignment
            validateattributes(value,{'numeric'},{'scalar'},'prefix','value',2)
            pre = pre@double(value); % required for subclass of double
            pre.name = name;
            pre.value = value;
            % aliases
            if nargin>2 && ~isempty(aliases)
                validateattributes(aliases,{'cell'},{'vector'},'unit','aliases',4)
                assert(iscellstr(aliases),'unit:aliases',...
                    'Aliases must be a cell string.')
                pre.aliases = aliases;
            end
        end
        % no subsref or subsasgn
        function F = subsref(pre,s)
            switch s(1).type
                case {'()','{}'}
                    error('prefix:subsref','Prefix is scalar - do not index.')
                otherwise
                    F = subsref@double(pre,s);
            end
        end
        function F = subsasgn(pre1,s,pre2)
            switch s(1).type
                case {'()','{}'}
                    error('prefix:subsasgn','Prefix is scalar - do not index.')
                otherwise
                    F = subsasgn@double(pre1,s,pre2);
            end
        end
        % no horzcat, vertcat or cat
        function F = times(pre,u)
            validateattributes(u,{'Quantities.unit'},{'scalar'},'times','u',2)
%             assert(u.value==1,'prefix:times',...
%                 'Prefixes can only be combined with base units.')
            F = Quantities.unit([pre.name,u.name],u.dimensionality,...
                pre.value.*u);
        end
        function F = mtimes(pre,u)
            F = pre.*u;
        end
    end
end
