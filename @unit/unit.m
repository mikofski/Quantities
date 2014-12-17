classdef unit < double
    properties (SetAccess = immutable)
        name = 'dimensionless'
        dimensionality = [] % dimensionality
        value = 1 % SI equivalent value
        aliases = {}
        bases = {}
        degrees = 0
    end
    properties (Constant)
        DIMENSIONLESS = Quantities.unit;
    end
    methods
        function u = unit(name,dimensionality,value,aliases)
            if nargin<1
                value = 1;
            end
            u = u@double(value); % required for subclass of double
            if nargin>0
                u.name = name;
                u.dimensionality = dimensionality;
                u.value = value;
                [u.bases,u.degrees] = Quantities.unit.parse_name(u.name);
            end
            if nargin>3
                u.aliases = aliases;
            end
        end
        function disp(u)
            F = sprintf('\t%s [%s] =\n',u.name,u.dimensionality);
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
        function F = ge(u,v)
            % GREATER OR EQUAL Test unit dimensionality subset.
            if isscalar(u) && isscalar(v)
                F = strcmp(u.dimensionality,v.dimensionality) ||...
                    (u.is_dimensionless && v.is_dimensionless);
            elseif isscalar(u)
                vdimensionality = cellfun(@(w)w.dimensionality,...
                    v,'UniformOutput',false);
                v_is_dimensionless = cellfun(@(w)w.is_dimensionless,...
                    v,'UniformOutput',false);
                F = strcmp(u.dimensionality,vdimensionality) ||...
                    (u.is_dimensionless && all(v_is_dimensionless));
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
        function F = times(u,v)
            % TIMES Element-by-element array multiplication.
            if isa(u,'Quantities.unit') &&...
                    ~(isa(v,'Quantities.unit') || isa(v,'Quantities.quantity'))
                F = Quantities.quantity(v,0,u);
            elseif isa(v,'Quantities.unit') &&...
                    ~(isa(u,'Quantities.unit') || isa(u,'Quantities.quantity'))
                F = Quantities.quantity(u,0,v);
            elseif isa(u,'Quantities.unit') && isa(v,'Quantities.unit')
                if u.is_dimensionless && ~v.is_dimensionless
                    F = v;
                elseif ~u.is_dimensionless && v.is_dimensionless
                    F = u;
                elseif u.is_dimensionless && v.is_dimensionless
                    F = Quantities.unit.DIMENSIONLESS;
                elseif strcmp(u.name,v.name)
                    uname = [u.name,'^',num2str(u.degrees+v.degrees)];
                    sz = size(u.aliases);ualiases = cell(sz);
                    for n = 1:prod(sz)
                        ualiases{n} = [u.aliases{n},'^',num2str(u.degrees+v.degrees)];
                    end
                    F = Quantities.unit(uname,...
                        [u.dimensionality,'^',num2str(u.degrees+v.degrees)],...
                        u.value.*v.value,ualiases);
                else
                    uname = [u.name,'*',v.name];
                    F = Quantities.unit(uname,[u.dimensionality,'*',v.dimensionality],...
                        u.value.*v.value,{});
                end
            else
                % u is a unit and v is a quantity
                if u.is_dimensionless && ~v.unit.is_dimensionless
                    F = v;
                elseif ~u.is_dimensionless && v.unit.is_dimensionless
                    F = Quantities.quantity(v.average,v.variance,u);
                else
                    u = u.*v.unit;
                    F = Quantities.quantity(v.average,v.variance,u);
                end
            end
        end
        function F = combine(u)
            % COMBINE Combine units.
            F = 1;
            for b = unique(u.bases)
                idx = strcmp(b,u.bases);
                degree = sum(u.degrees(idx));
                if degree==1
                    uname = b{1};
                else
                    uname = [b{1},'^',num2str(degree)];
                end
                F = F*unit(uname,'',1,{});
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
    methods (Static)
        function [uname,subexps] = parse_parentheses(uname,subexps)
            % find parenthetic subexpressions
            if nargin<2
                subexps = {};
            end
            [tks,splits] = regexp(uname,'\(([@\w +-*/^]*)\)','tokens','split');
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
        function [bases,degrees] = parse_dimensions(uname)
            % find dimensionality
            [matches,splits] = regexp(uname,'[*/]*','match','split');
            if isempty(splits{1})
                bases = {};
                degrees = [];
                return
            end
            sz = size(splits);
            bases = cell(sz);
            degrees = ones(sz);
            tks = regexp(splits{1},'(\w+)\^((?<=\^)[.+-\d]+)','tokens');
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
                tks = regexp(splits{n+1},'(\w+)\^((?<=\^)[.+-\d]+)','tokens');
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
            [bases,degrees] = Quantities.unit.parse_dimensions(uname);
            next = cell(1,2);
            for n = 1:numel(subexps)
                if all(cellfun(@isempty,next))
                    [subbases,subdegrees] = Quantities.unit.parse_dimensions(subexps{n});
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
                    [next{:}] = Quantities.unit.parse_dimensions(subexps{n+1});
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
