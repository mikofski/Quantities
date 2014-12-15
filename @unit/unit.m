classdef unit < double
    properties (SetAccess = immutable)
        name
        dimensionality % dimensionality
        value % SI equivalent value
        aliases
        bases
        degrees = 1
        DOF
    end
    methods
        function u = unit(name,dimensionality,value,aliases)
            u = u@double(value);
            u.name = name;
            u.dimensionality = dimensionality;
            u.value = value;
            u.aliases = aliases;
            [u.bases,u.degrees] = Quantities.unit.parse_name(u.name);
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
            elseif isscalar(u)
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
        function F = times(u,v)
            % element-by-element array multiplication
            if isa(u,'Quantities.unit') &&...
                    ~(isa(v,'Quantities.unit') || isa(v,'Quantities.quantity'))
                F = Quantities.quantity(v,0,u.name);
            elseif isa(v,'Quantities.unit') &&...
                    ~(isa(u,'Quantities.unit') || isa(u,'Quantities.quantity'))
                F = Quantities.quantity(u,0,v.name);
            elseif isa(u,'Quantities.unit') && isa(v,'Quantities.unit')
                F = Quantities.unit();
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
                uname = [uname,'@',num2str(m+n),splits{n+1}]; %#ok<AGROW>
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
                    bases = [bases,subbases]; %#ok<AGROW>
                    degrees = [degrees,subdegrees*degree]; %#ok<AGROW>
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
