classdef unit < double
    properties (SetAccess = immutable)
        name = 'dimensionless'
        dimensionality = [] % dimensionality
        value = 1 % SI equivalent value
        offset = 0 % offset from reference value
        aliases = {}
        bases = {}
        degrees = 0
        dimensions = {}
    end
    properties (Constant)
        DIMENSIONLESS = Quantities.unit;
    end
    methods
        function u = unit(name,dimensionality,value,aliases)
            % default value for no-arg constructor
            if nargin<1
                value = 1;
            end
            % value must be either numeric or a quantity class
            validateattributes(value,{'Quantities.quantity','numeric'},...
                {'scalar'},'unit','value',3)
            u = u@double(value); % required for subclass of double
            % parse arguments
            if nargin>0
                % name must be a string
                validateattributes(name,{'char'},{'row'},'unit','name',1)
                u.name = name;
                % dimensionality must be null or dimensionality class
                if ~isempty(dimensionality)
                    validateattributes(dimensionality,...
                        {'Quantities.dimension'},{'scalar'},'unit',...
                        'dimensionality',2)
                    u.dimensionality = dimensionality;
                    u.dimensions = u.dimensionality.dimensions;
                    % TODO: redundant, refactor to use
                    % u.dimensionality.dimensions everywhere!
                end
                % value must equal 1 if not a quantity class
                if ~isa(value,'Quantities.quantity')
                    assert(value==1,'unit:value',...
                        'Value must be a quantity or set to 1 for base units.')
                end
                u.value = value;
                % get base units and their degrees
                % TODO: these should be unit class objects
                [u.bases,u.degrees] = Quantities.unit.parse_name(u.name);
            end
            % parse aliases
            if nargin>3 && ~isempty(aliases)
                validateattributes(aliases,{'cell'},{'vector'},...
                    'unit','aliases',4)
                assert(iscellstr(aliases),'unit:aliases','Aliases must be a cell string.')
                u.aliases = aliases;
            end
        end
        function disp(u)
            F = sprintf('\t%s [%s] =\n',u.name,char(u.dimensionality));
            if isa(u.value,'Quantities.quantity')
                H = sprintf('%s',char(u.value));
            else
                H = sprintf('\t%g [%s]\n',u.value,u.name);
            end
            if ~isempty(u.aliases)
                G = sprintf(['\t(%s',repmat(', %s',[1,numel(u.aliases)-1]),')\n'],...
                    u.aliases{:});
            else
                G = '';
            end
            fprintf('%s%s%s',F,H,G)
        end
        % no subsref or subsasgn
        function F = subsref(u,s)
            switch s(1).type
                case {'()','{}'}
                    error('unit:subsref','Unit is scalar - do not index Unit.')
                otherwise
                    F = subsref@double(u,s);
            end
        end
        function F = subsasgn(u,s,v)
            switch s(1).type
                case {'()','{}'}
                    error('unit:subsasgn','Unit is scalar - do not index Unit.')
                otherwise
                    F = subsasgn@double(u,s,v);
            end
        end
        % no horzcat, vertcat or cat
        function F = ge(u,v)
            % GREATER OR EQUAL Test unit dimensionality subset.
            if isa(u,'Quantities.unit') && isa(v,'Quantities.unit')
                F = strcmp(u.dimensionality,v.dimensionality) ||...
                    (u.is_dimensionless && v.is_dimensionless);
            elseif iscell(v)
                vdimensionality = cellfun(@(w)w.dimensionality,...
                    v,'UniformOutput',false);
                v_is_dimensionless = cellfun(@(w)w.is_dimensionless,...
                    v,'UniformOutput',false);
                F = strcmp(u.dimensionality,vdimensionality) ||...
                    (u.is_dimensionless && all(v_is_dimensionless));
            elseif iscell(u)
                F = v>=u;
            end
        end
        function F = le(u,v)
            F = u>=v;
        end
        function F = gt(u,v)
            F = u>=v && u~=v;
        end
        function F = lt(u,v)
            F = u>=v && u~=v;
        end
        function F = eq(u,v)
            % EQUAL Test unit equality
            if isscalar(u) && isscalar(v)
                F = strcmp(u.name,v.name);
            elseif isscalar(u)
                vnames = cellfun(@(w)w.name,v,'UniformOutput',false);
                F = strcmp(u.name,vnames);
            end
        end
        function F = uplus(u)
            F = u;
        end
        function F = uminus(u)
            F = -1.*u;
        end
        function F = plus(u,v)
            if ~isa(v,'Quantities.unit') && u.is_dimensionless &&...
                    ~isa(v,'Quantities.quantity')
                % u is dimensionless, v is double
                F = Quantities.quantity(1+v,0,Quantities.unit.DIMENSIONLESS);
            elseif ~isa(u,'Quantities.unit') && v.is_dimensionless &&...
                    ~isa(u,'Quantities.quantity')
                % v is dimensionless, u is double
                F = Quantities.quantity(1+u,0,Quantities.unit.DIMENSIONLESS);
            elseif isa(u,'Quantities.unit') && isa(v,'Quantities.unit')
                % both units
                if u==v
                    F = Quantities.quantity(2,0,u);
                elseif u>v
                    if u.value~=1 && v.value~=1
                        F = u.value + v.value;
                    elseif u.value==1
                        F = v.value+u;
                    else
                        F = u.value+v;
                    end
                else
                    error('unit:incompatibleUnits',...
                        'Units must have same dimensionality for addition.')
                end
            else
                % u is a unit and v is a quantity
                if u==v.units
                    F = v+u;
                elseif u>v.units
                    if u.value==1
                        F = v.to_base+u;
                    else
                        F = v.to_base+u.value;
                    end
                else
                    error('unit:incompatibleUnits',...
                        'Units must have same dimensionality for addition.')
                end
            end
        end
        function F = minus(u,v)
            F = u+(-v);
        end
        function F = times(u,v)
            % TIMES Element-by-element array multiplication.
            if ~isa(v,'Quantities.unit') && ~isa(v,'Quantities.quantity')
                % v is double
                if v==1
                    F = u; % identity
                else
                    F = Quantities.quantity(v,zeros(size(v)),u);
                end
            elseif ~isa(u,'Quantities.unit') && ~isa(u,'Quantities.quantity')
                % u is double
                F = v.*u; % call times() recursively
            elseif isa(u,'Quantities.unit') && isa(v,'Quantities.unit')
                % both u & v are units
                if u.is_dimensionless && ~v.is_dimensionless
                    F = v; % u is dimensionless
                elseif ~u.is_dimensionless && v.is_dimensionless
                    F = u; % v is dimensionless
                elseif u.is_dimensionless && v.is_dimensionless
                    F = Quantities.unit.DIMENSIONLESS; % both dimensionless
                else
                    uname = ['(',u.name,')*(',v.name,')'];
                    if u.value==1 && v.value==1
                        F = Quantities.unit(uname,...
                            u.dimensionality.*v.dimensionality,...
                            1);
                    elseif v.value==1
                        F = Quantities.unit(uname,...
                            u.dimensionality.*v.dimensionality,...
                            u.value.*v);
                    elseif u.value==1
                        F = Quantities.unit(uname,...
                            u.dimensionality.*v.dimensionality,...
                            u.*v.value);
                    else
                        F = Quantities.unit(uname,...
                            u.dimensionality.*v.dimensionality,...
                            u.value.*v.value);
                    end
                    F = F.combine; % combine units
                end
            else
                % u is a unit and v is a quantity
                F = v.*u;
            end
        end
        function F = rdivide(u,v)
            % RDIVIDE Units division.
            if ~isa(v,'Quantities.unit') && ~isa(v,'Quantities.quantity')
                if v==1
                    F = u;
                else
                    F = Quantities.quantity(1./v,0,u);
                end
            elseif ~isa(u,'Quantities.unit') && ~isa(u,'Quantities.quantity')
                F = Quantities.unit.DIMENSIONLESS;
                idx = 0;
                for b = v.bases
                    idx = idx+1;
                    degree = -v.degrees(idx);
                    if degree==1
                        uname = b{1};
                    else
                        uname = [b{1},'^',num2str(degree)];
                    end
                    F = F.*Quantities.unit(uname,[],1);
                end
                F = Quantities.unit(F.name,1./v.dimensionality,1./v.value);
            elseif isa(u,'Quantities.unit') && isa(v,'Quantities.unit')
                if u.is_dimensionless && ~v.is_dimensionless
                    F = 1./v;
                elseif ~u.is_dimensionless && v.is_dimensionless
                    F = u;
                elseif u.is_dimensionless && v.is_dimensionless
                    F = Quantities.unit.DIMENSIONLESS;
                else
                    uname = ['(',u.name,')/(',v.name,')'];
                    if u.value==1 && v.value==1
                        F = Quantities.unit(uname,u.dimensionality./v.dimensionality,...
                            1);
                    elseif v.value==1
                        F = Quantities.unit(uname,u.dimensionality./v.dimensionality,...
                            u.value./v);
                    elseif u.value==1
                        F = Quantities.unit(uname,u.dimensionality./v.dimensionality,...
                            u./v.value);
                    else
                        F = Quantities.unit(uname,u.dimensionality./v.dimensionality,...
                            u.value./v.value);
                    end
                    F = F.combine; % combine units
                end
            else
                % u is a unit and v is a quantity
                F = v.\u; % = 1./v.*u;
            end
        end
        function F = ldivide(u,v)
            F = v./u;
        end
        function F = mtimes(u,v)
            F = u.*v;
        end
        function F = mrdivide(u,v)
            F = u./v;
        end
        function F = mldivide(u,v)
            F = u.\v;
        end
        function F = power(u,n)
            F = 1;
            if n==0
                return
            end
            for m = 1:abs(n)
                if n>0
                    F = F.*u;
                else
                    F = F./u;
                end
            end
        end
        function F = mpower(u,n)
            F = u.^n;
        end
        function F = combine(u)
            % COMBINE Combine units.
            unique_bases = unique(u.bases);
            uname = cell(1,numel(unique_bases));
            jdx = 0;
            for b = unique_bases
                jdx = jdx+1;
                idx = strcmp(b,u.bases);
                degree = sum(u.degrees(idx));
                if degree==0
                    continue
                elseif degree==1
                    uname(jdx) = b;
                else
                    uname{jdx} = [b{1},'^',num2str(degree)];
                end
            end
            if iscellstr(uname)
                uname = strjoin(uname,'*');
                F = Quantities.unit(uname,u.dimensionality,u.value,u.aliases);
            else
                F = Quantities.unit.DIMENSIONLESS;
            end
        end
        function F = is_dimensionless(u)
            F = strcmp(u.name,Quantities.unit.DIMENSIONLESS.name);
        end
        function F = convert(x,y)
            % CONVERT Convert units.
            if x>=y % check dimensionality
                F = x;
            end
        end
    end
    % TODO: maybe theses should be in unitRegistry?
    % TODO: ``srtrim()`` all bases and dimensions!
    % TODO: ``sort()`` all bases and dimensions!
    % TOOD: apply ``unit()`` to bases and ``dimensionality()`` to dimmensions?
    methods (Static)
        function [uname,subexps] = parse_parentheses(uname,subexps)
            % find parenthetic subexpressions
            if nargin<2
                subexps = {};
            end
            [tks,splits] = regexp(uname,'\(([@\w +\-*/^]*)\)','tokens','split');
            if isempty(tks)
                return
            end
            m = numel(subexps);
            subexps = [subexps,[tks{:}]];
            uname = splits{1};
            for n = 1:numel(tks)
                uname = [uname,'@',num2str(m+n),splits{n+1}];
            end
            [uname,subexps] = Quantities.unit.parse_parentheses(uname,subexps);
        end
        function [bases,degrees] = parse_bases(uname)
            % find bases
            [matches,splits] = regexp(uname,'[*/]*','match','split');
            if isempty(splits{1})
                bases = {};
                degrees = [];
                return
            end
            sz = size(splits);
            bases = cell(sz);
            degrees = ones(sz);
            tks = regexp(splits{1},'(@?\w+)\^((?<=\^)[.+\-\d]+)','tokens');
            if ~isempty(tks)
                bases(1) = tks{1}(1);
                degrees(1) = str2double(tks{1}{2});
            else
                bases(1) = splits(1);
            end
            for n = 1:numel(matches)
                switch matches{n}
                    case '*'
                        numerator_denominator = 1;
                    case '/'
                        numerator_denominator = -1;
                end
                tks = regexp(splits{n+1},'(@?\w+)\^((?<=\^)[.+\-\d]+)','tokens');
                if ~isempty(tks)
                    bases(n+1) = tks{1}(1);
                    degrees(n+1) = str2double(tks{1}{2})*numerator_denominator;
                else
                    bases(n+1) = splits(n+1);
                    degrees(n+1) = numerator_denominator;
                end
            end
        end
        function [bases,degrees] = parse_name(uname)
            % parse units into base units and their degrees
            [uname,subexps] = Quantities.unit.parse_parentheses(uname);
            [bases,degrees] = Quantities.unit.parse_bases(uname);
            next = cell(1,2);
            for n = 1:numel(subexps)
                if all(cellfun(@isempty,next))
                    [subbases,subdegrees] = Quantities.unit.parse_bases(subexps{n});
                else
                    [subbases,subdegrees] = next{:};
                end
                idx = strcmp(['@',num2str(n)],bases);
                if any(idx)
                    bases(idx) = [];
                    degree = degrees(idx);
                    degrees(idx) = [];
                    bases = [bases,subbases];
                    degrees = [degrees,subdegrees*degree];
                else
                    [next{:}] = Quantities.unit.parse_bases(subexps{n+1});
                    idx = strcmp(['@',num2str(n)],next{1});
                    next{1}(idx) = [];
                    degree = next{2}(idx);
                    next{2}(idx) = [];
                    next{1} = [next{1},subbases];
                    next{2} = [next{2},subdegrees*degree];
                end
            end
        end
    end
end
