classdef dimension < double
    properties (SetAccess = immutable)
        name % name of dimension
        value = 1 % value of dimension in terms of other dimensions
        dimensions = {} % dimensions
        degrees % power of each dimension
    end
    methods
        function dim = dimension(name,value)
            % default value
            if nargin<2
                value = 1;
            end
            validateattributes(name,{'char'},{'row'},'dimension','name',1)
            % value must be either numeric or a dimension class
            % since 'Quantities.dimension' is double it _is_ numeric
            % can't filter real/finite without allowing index/assignment
            validateattributes(value,{'numeric'},{'scalar'},'dimension','value',2)
            dim = dim@double(value); % required for subclass of double
            dim.name = name;
            if nargin>1
                % value must equal 1 if not a dimension class
                if ~isa(value,'Quantities.dimension')
                    assert(value==1,'dimension:value',...
                        'Value must be a dimension or set to 1 for base dimensions.')
                end
                dim.value = value;
            end
            if dim.value==1
                [dim.dimensions, dim.degrees] = Quantities.unit.parse_name(dim.name);
            else
                [dim.dimensions, dim.degrees] = Quantities.unit.parse_name(dim.value.name);
            end
        end
        function str = char(dim)
            str = dim.name;
        end
        % no subsref or subsasgn
        function F = subsref(dim,s)
            switch s(1).type
                case {'()','{}'}
                    error('dimension:subsref','Dimension is scalar - do not index.')
                otherwise
                    F = subsref@double(dim,s);
            end
        end
        function F = subsasgn(dim1,s,dim2)
            switch s(1).type
                case {'()','{}'}
                    error('dimension:subsasgn','Dimension is scalar - do not index.')
                otherwise
                    F = subsasgn@double(dim1,s,dim2);
            end
        end
        % no horzcat, vertcat or cat
        function F = times(dim1,dim2)
            if isa(dim1,'Quantities.dimension') && isa(dim2,'Quantities.dimension')
                if dim1.value==1 && isa(dim2.value,'Quantities.dimension')
                    F = dim1.*dim2.value;
                    return
                elseif isa(dim1.value,'Quantities.dimension') && dim2.value==1
                    F = dim1.value.*dim2;
                    return
                else
                    dimval = dim1.value.*dim2.value;
                end
                F = Quantities.dimension(['(',dim1.name,')*(',dim2.name,')'],...
                    dimval);
                F = F.combine;
            elseif isnumeric(dim1)
                F = dim2;
            elseif isnumeric(dim2)
                F = dim1;
            else
                error('dimension:times','Dimensions can only operate on other dimensions.')
            end
        end
        function F = mtimes(dim1,dim2)
            F = dim1.*dim2;
        end
        function F = rdivide(dim1,dim2)
            if isa(dim1,'Quantities.dimension') && isa(dim2,'Quantities.dimension')
                if dim1.value==1 && isa(dim2.value,'Quantities.dimension')
                    F = dim1./dim2.value;
                    return
                elseif isa(dim1.value,'Quantities.dimension') && dim2.value==1
                    F = dim1.value./dim2;
                    return
                else
                    dimval = dim1.value./dim2.value;
                end
                F = Quantities.dimension(['(',dim1.name,')/(',dim2.name,')'],...
                    dimval);
                F = F.combine;
            elseif isnumeric(dim1)
                F = Quantities.dimension(['(',dim2.name,')^-1']);
                F = F.combine;
            elseif isnumeric(dim2)
                F = dim1;
            else
                error('dimension:divide','Dimensions can only operate on other dimensions.')
            end
        end
        function F = ldivide(dim1,dim2)
            F = dim2./dim1;
        end
        function F = mrdivide(dim1,dim2)
            F = dim1./dim2;
        end
        function F = mldivide(dim1,dim2)
            F = dim2./dim1;
        end
        function F = power(dim,x)
            validateattributes(x,{'numeric'},{'scalar','real','finite'},...
                'power','x',2)
            F = 1;
            if x==0
                return
            end
            F = Quantities.dimension(['(',dim.name,')^',num2str(x)],dim.value.^x);
            F = F.combine;
        end
        function F = mpower(dim,x)
            F = dim.^x;
        end
        function tf = strcmp(dim1,dim2)
            % STRCMP Compare dimensions. Overloads string compare.
            tf = false; % return false if not dimension or string
            if isa(dim1,'Quantities.dimension') && isa(dim2,'Quantities.dimension')
                tf = numel(dim1.dimensions)==numel(dim2.dimensions);
                if ~tf
                    return
                end
                [dims1,idx1] = sort(dim1.dimensions);
                [dims2,idx2] = sort(dim2.dimensions);
                tf = tf && all(strcmp(dims1,dims2));
                if ~tf
                    return
                end
                tf = tf && all(dim1.degrees(idx1)==dim2.degrees(idx2));
            elseif ischar(dim2)
                % TODO: convert all names, bases and dimensions to lower case
                tf_by_name = strcmp(dim1.name,dim2);
                tf_by_dims = strcmp(dim1,Quantities.dimension('dim2',dim2));
                tf = tf_by_name || tf_by_dims;
            end
        end
        function tf = eq(dim1,dim2)
            tf = strcmp(dim1,dim2);
        end
        function F = combine(dim)
            % COMBINE Combine dimensions.
            unique_dims = unique(dim.dimensions);
            dim_name = cell(size(unique_dims));
            jdx = 0;
            for d = unique_dims
                jdx = jdx+1;
                idx = strcmp(d,dim.dimensions);
                degree = sum(dim.degrees(idx));
                if degree==0
                    dim_name(jdx) = []; % pop unused cell
                    jdx = jdx-1; % adjust index
                    continue
                elseif degree==1
                    dim_name(jdx) = d;
                else
                    dim_name{jdx} = [d{1},'^',num2str(degree)];
                end
            end
            if ~isempty(dim_name) && iscellstr(dim_name)
                dim_name = strjoin(dim_name,'*');
                F = Quantities.dimension(dim_name,dim.value);
            else
                F = [];
            end
        end
    end
end
