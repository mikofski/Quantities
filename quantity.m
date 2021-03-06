classdef quantity < double
    properties (SetAccess = immutable)
        average % first moment = trap(x,y)/trap(x)
        variance % second moment = trap(x,y^2 - average^2)/trap(x)
        stdev % standard deviation = sqrt(variance)
        relative % relative standard deviation = standard deviation / average
        units % units
    end
    methods
        function x = quantity(average,varargin)
            % parse inputs
            p = inputParser;
            p.addRequired('average',...
                @(average)validateattributes(average,{'numeric'},...
                {'real'},'quantity','average'));
            p.addOptional('stdev',zeros(size(average)),...
                @(stdev)validateattributes(stdev,{'numeric'},...
                {'real','size',size(average),'nonnegative'},...
                'quantity','stdev'))
            p.addOptional('units',Quantities.unit.DIMENSIONLESS,...
                @(units)validateattributes(units,{'Quantities.unit'},{'scalar'},...
                'quantity','units'))
            p.addParameter('variance',zeros(size(average)),...
                @(variance)validateattributes(variance,{'numeric'},...
                {'real','size',size(average),'nonnegative'},...
                'quantity','variance'))
            p.parse(average,varargin{:});
            args = p.Results;
            % superclass constructor
            x = x@double(args.average); % required for subclass of double
            x.average = double(x); % coerce quantity to double
            % calculate variance or standard deviation, depending on args
            if any(strcmp('variance',p.UsingDefaults))
                x.stdev = double(args.stdev); % cast numeric as double
                x.variance = x.stdev.^2;
            else
                x.variance = double(args.variance); % cast numeric as double
                x.stdev = sqrt(x.variance);
            end
            % calculate standard deviation relative to average
            x.relative = x.stdev./x.average;
            x.units = args.units; % assign units
        end
        function F = char(x)
            if ismatrix(x)
                fmt1 = '\t%g � %g [%s]'; % char(177)
                fmtN = '%s, %g � %g [%s]';
                dims = size(x);
                % 1st row & column string
                F = subsref(x,substruct('()',{1,1}));
                sc = sprintf(fmt1,F.average,F.stdev,F.units.name);
                % 1st row string
                for n = 2:dims(2)
                    F = subsref(x,substruct('()',{1,n}));
                    sc = sprintf(fmtN,sc,F.average,F.stdev,F.units.name);
                end
                sr = sprintf('%s;\n',sc);
                for m = 2:dims(1)
                    F = subsref(x,substruct('()',{m,1}));
                    sc = sprintf(fmt1,F.average,F.stdev,F.units.name);
                    for n = 2:dims(2)
                        F = subsref(x,substruct('()',{m,n}));
                        sc = sprintf(fmtN,sc,F.average,F.stdev,F.units.name);
                    end
                    sr = sprintf('%s%s;\n',sr,sc);
                end
                F = sprintf('%s',sr);
            else
                dims = size(x);
                dimstring = sprintf('%d',dims(1)); % char(215)
                for dim = dims(2:end)
                    dimstring = sprintf('%s�%d',dimstring,dim);
                end
                F = sprintf('Quantities.quantity <%s>\n',dimstring);
            end
        end
        function disp(x)
            % DISP Display quantity.
            if ismatrix(x)
                fprintf('%s',char(x));
            else
                disp@double(x)
            end
        end
        function F = transpose(x)
            F = Quantities.quantity(transpose(x.average),...
                transpose(x.stdev),x.units);
        end
        function F = ctranspose(x)
            F = Quantities.quantity(ctranspose(x.average),...
                ctranspose(x.stdev),x.units);
        end
        function F = subsref(x,s)
            switch s(1).type
                case '()'
                    F = Quantities.quantity(subsref(x.average,s(1)),...
                        subsref(x.stdev,s(1)),x.units);
                    if numel(s)>1
                        F = subsref@double(F,s(2:end));
                    end
                case '{}'
                    s(1).type = '()';
                    F = subsref(x.average,s);
                otherwise
                    F = subsref@double(x,s);
            end
        end
        function F = subsasgn(x,s,y)
            switch s(1).type
                case '()'
                    if numel(s)>1
                        F = subsasgn@double(subsref(x,s(1)),s(2:end),y);
                    else
                        assert(x.units>=y.units,...
                            'quantity:dimensionalMismatch',...
                            'Subscript assignment units must be same dimensionality.')
                        y = y.convert(x.units); % convert units to original
                        F = Quantities.quantity(subsasgn(x.average,s,y.average),...
                            subsasgn(x.stdev,s,y.stdev),...
                            x.units);
                    end
                case '{}'
                    s(1).type = '()';
                    F = Quantities.quantity(subsasgn(x.average,s,y),...
                        x.stdev,x.units);
                otherwise
                    F = subsasgn@double(x,s,y);
            end
        end
        function F = horzcat(varargin)
            avg_ = cellfun(@(x)x.average,varargin,'UniformOutput',false);
            stdev_ = cellfun(@(x)x.stdev,varargin,'UniformOutput',false);
            units_ = cellfun(@(x)x.units,varargin,'UniformOutput',false);
            assert(units_{1}>=units_(2:end),...
                'quantity:dimensionalMismatch',...
                'Horizontal concatenation units must be same dimensionality.')
            F = Quantities.quantity([avg_{:}],[stdev_{:}],units_{1});
        end
        function F = vertcat(varargin)
            avg_ = cellfun(@(x)x.average,varargin,'UniformOutput',false);
            stdev_ = cellfun(@(x)x.stdev,varargin,'UniformOutput',false);
            units_ = cellfun(@(x)x.units,varargin,'UniformOutput',false);
            assert(units_{1}>=units_(2:end),...
                'quantity:dimensionalMismatch',...
                'Vertical concatenation units must be same dimensionality.')
            F = Quantities.quantity(vertcat(avg_{:}),vertcat(stdev_{:}),...
                units_{1});
        end
        function F = cat(dim,varargin)
            if dim==1
                F = vertcat(varargin{:});
            elseif dim==2
                F = horzcat(varargin{:});
            end
        end
        function F = plus(x,y)
            % F = x+y
            % dF^2 = (1*dx).^2+(1*dy).^2
            x = Quantities.quantity.as_quantity(x);
            y = Quantities.quantity.as_quantity(y);
            x = x.to_base;y = y.to_base;
            if x~=0 && y~=0
                assert(x.units==y.units,'quantity:plus',...
                    'Quantity must have same units for addition.');
            end
            F = Quantities.quantity(plus@double(x,y),'units',x.units,...
                'variance',x.variance+y.variance);
        end
        function F = minus(x,y)
            % F = x-y
            % dF^2 = (1*dx).^2+(-1*dy).^2
            x = Quantities.quantity.as_quantity(x);
            y = Quantities.quantity.as_quantity(y);
            x = x.to_base;y = y.to_base;
            if x~=0 && y~=0
                assert(x.units==y.units,'quantity:plus',...
                    'Quantity must have same units for subtraction.');
            end
            F = Quantities.quantity(minus@double(x,y),'units',x.units,...
                'variance',x.variance+y.variance); % (-1)^2 = 1
        end
        function F = times(x,y)
            % F = x.*y
            % dF^2 = (y.*dx).^2+(x.*dy).^2
            x = Quantities.quantity.as_quantity(x);
            y = Quantities.quantity.as_quantity(y);
            x = x.to_base;y = y.to_base;
            unit = x.units.*y.units; % combine units
            F = Quantities.quantity(times@double(x,y),'units',unit,'variance',...
                y.average.^2.*x.variance+x.average.^2.*y.variance);
        end
        function F = mtimes(x,y)
            % F_ik = x_ij*y_jk = x_i1*y_1k + x_i2*y_2k + x_i3*y_3k
            % dF_ik^2 = dx_ij.^2*y_jk.^2+x_ij.^2*dy_jk.^2
            function dF = Fvar(xavg,yavg,xvariance,yvariance)
                dF = zeros(size(xavg,1),size(yavg,2));
                for idx = 1:size(xavg,1)
                    for kdx = 1:size(yavg,2)
                        dF(idx,kdx) = xvariance(idx,:)*yavg(:,kdx).^2+...
                            xavg(idx,:).^2*yvariance(:,kdx);
                    end
                end
            end
            x = Quantities.quantity.as_quantity(x);
            y = Quantities.quantity.as_quantity(y);
            x = x.to_base;y = y.to_base;
            unit = x.units*y.units; % combine units
            F = Quantities.quantity(mtimes@double(x,y),'units',unit,...
                'variance',Fvar(x.average,y.average,x.variance,y.variance));
        end
        function F = power(x,y)
            % F = x.^y
            % dF^2 = (y.*x.^(y-1).*dx).^2+(log(x).*x.^y.*dy).^2)
            x = Quantities.quantity.as_quantity(x);
            y = Quantities.quantity.as_quantity(y);
            x = x.to_base;y = y.to_base;
            assert(y.units.is_dimensionless,'quantity:power',...
                'Power must be dimensionless.')
            unit = x.units^double(y); % combine units
            F = Quantities.quantity(power@double(x,y),'units',unit,'variance',...
                (y.average.*x.average.^(y.average-1)).^2.*x.variance+...
                (log(x.average).*x.average.^y.average).^2.*y.variance);
        end
        function F = mpower(x,y)
            % MPOWER Matrix power.
            % If X and Y are scalar then returns POWER(X,Y). If Y is a
            % scalar non-negative integer then repeated matrix
            % multiplication is used. Otherwise QUANTITY is coerced to
            % DOUBLE.
            if isscalar(x) && isscalar(y)
                F = x.^y;
            elseif isscalar(y) && round(y)==y && y>0
                F = x;
                for n = 1:y-1
                    F = F*x;
                end
            else
                F = mpower@double(x,y);
            end
        end
        function F = sqrt(x)
            F = x.^0.5;
        end
        function F = rdivide(x,y)
            % F = x./y
            % dF^2 = (1./y.*dx).^2+(-x./y.^2.*dy).^2
            x = Quantities.quantity.as_quantity(x);
            y = Quantities.quantity.as_quantity(y);
            x = x.to_base;y = y.to_base;
            unit = x.units./y.units; % combine units
            F = Quantities.quantity(rdivide@double(x,y),'units',unit,...
                'variance',1./y.average.^2.*x.variance+...
                (x.average./y.average.^2).^2.*y.variance); % (-1)^2 = 1
        end
        function F = mrdivide(x,y)
            if isscalar(x) && isscalar(y)
                F = x./y;
            else
                F = mrdivide(x,y);
            end
        end
        function F = ldivide(x,y)
            % F = x.\y = y./x
            % dF^2 = (1./x.*dy).^2+(-y./x.^2.*dx).^2
            F = y./x;
        end
        function F = mldivide(x,y)
            if isscalar(x) && isscalar(y)
                F = x.\y;
            else
                F = mldivide(x,y);
            end
        end
        function F = uplus(x)
            % F = +x
            F = Quantities.quantity(uplus@double(x),x.stdev,x.units);
        end
        function F = uminus(x)
            % F = -x
            F = Quantities.quantity(uminus@double(x),x.stdev,x.units);
        end
        function F = sin(x)
            % F = sin(x)
            % dF^2 = (cos(x).*dx).^2
            assert(isempty(x.units.dimensionality),'quantity:sin',...
                'Sine argument must be a dimensionless unit, IE: radians, degrees, etc.')
            x = x.to_base; % convert to radians
            F = Quantities.quantity(sin@double(x),'units',...
                Quantities.unit.DIMENSIONLESS,...
                'variance',cos(x.average).^2.*x.variance);
        end
        function F = cos(x)
            % F = cos(x)
            % dF^2 = (-sin(x).*dx).^2
            assert(isempty(x.units.dimensionality),'quantity:cos',...
                'Cosine argument must be a dimensionless unit, IE: radians, degrees, etc.')
            x = x.to_base; % convert to radians
            F = Quantities.quantity(cos@double(x),'units',...
                Quantities.unit.DIMENSIONLESS,...
                'variance',sin(x.average).^2.*x.variance); % (-1)^2 = 1
        end
        function F = tan(x)
            x_sin = sin(x);
            x_cos = cos(x);
            x_tan = x_sin./x_cos;
            x = x.to_base; % convert to radians
            F = Quantities.quantity(tan@double(x),'units',...
                Quantities.unit.DIMENSIONLESS,...
                'variance',x_tan.variance);
        end
        function F = log(x)
            % F = log(x)
            % dF^2 = (1/x.*dx).^2
            assert(x.units.is_dimensionless,'quantity:log',...
                'Logarithm must be dimensionless.')
            F = Quantities.quantity(log@double(x),'units',x.units,...
                'variance',1./x.average.^2.*x.variance);
        end
        function F = log2(x)
            % F = log(x)
            % dF^2 = (1/x/log(2).*dx).^2
            assert(x.units.is_dimensionless,'quantity:log2',...
                'Logarithm must be dimensionless.')
            F = Quantities.quantity(log2@double(x),'units',x.units,...
                'variance',1./(log(2)*x.average).^2.*x.variance);
        end
        function F = log10(x)
            % F = log(x)
            % dF^2 = (1/x/log(10).*dx).^2
            assert(x.units.is_dimensionless,'quantity:log10',...
                'Logarithm must be dimensionless.')
            F = Quantities.quantity(log10@double(x),'units',x.units,...
                'variance',1./(log(10)*x.average).^2.*x.variance);
        end
        function F = to_base(x)
            % TO_BASE Convert units to base units.
            if x.units.value==1 && x.units.offset==0
                F = x;
                return
            end
            average_ = x.average*x.units.value.average;
            if x.units.offset~=0
                average_ = average_+x.units.offset.average;
            end
            %(dx*y)^2 = (y*dx)^2+(x*dy)^2, if dy==0 then d(x*y) = y*dx
            stdev_ = x.stdev*x.units.value.average;
            units_ = x.units.value.units;
            F = Quantities.quantity(average_,stdev_,units_).to_base;
        end
        function F = convert(x,u)
            % CONVERT Convert units.
            xunits_as_u = x.units.convert(u);
            conversion_factor = xunits_as_u.average;
            F = Quantities.quantity(x.average*conversion_factor,...
                x.stdev*conversion_factor,u);
        end
    end
    methods (Static)
        function F = as_quantity(x)
            if isa(x,'Quantities.quantity')
                F = x;
            elseif isa(x,'Quantities.unit')
                F = Quantities.quantity(1,0,x);
            else
                F = Quantities.quantity(x);
            end
        end
    end
end
