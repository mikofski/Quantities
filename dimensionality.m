classdef dimensionality
    % DIMENSIONALITY A class for dimensionality property of units.
    properties
        name % name of dimension
        value = 1 % value of dimension in terms of other dimensions
        dimensions = {} % dimensions
        degrees % power of each dimension
    end
    methods
        function dim = dimensionality(name,value)
            validateattributes(name,{'char'},{'row'},'dimensionality','name',1)
            dim.name = name;
            if nargin>1
                dim.value = value;
                [dim.dimensions, dim.degrees] = Quantities.unit.parse_name(value);
            end
        end
        function tf = strcmp(dim1,dim2)
            % STRCMP Compare dimensionality. Overloads string compare.
            if isa(dim1,'Quantities.dimensionality') && isa(dim2,'Quantities.dimensionality')
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
                tf_by_name = strcmpi(dim1.name,dim2);
                tf_by_dims = strcmpi(dim1,Quantities.dimensionality('dim2',dim2));
                tf = tf_by_name || tf_by_dims;
            end
        end
        function tf = eq(dim1,dim2)
            tf = strcmp(dim1,dim2);
        end
    end
end