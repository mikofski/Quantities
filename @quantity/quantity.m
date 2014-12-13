classdef quantity < double
    properties (SetAccess = immutable)
        average % first moment = trap(x,y)/trap(x)
        variance % second moment = trap(x,y^2 - average^2)/trap(x)
        stdev % standard deviation = sqrt(variance)
        relative % relative standard deviation = standard deviation / average
        units
    end
    methods
        function x = quantity(average,varargin)
            p = inputParser;
            p.addRequired('average',...
                @(arg)validateattributes(arg,{'numeric'},{'real','finite'},...
                'quantity','average'));
            p.addOptional('variance',zeros(size(average)),...
                @(arg)validateattributes(arg,{'numeric'},...
                {'real','finite','size',size(average),'nonnegative'},...
                'quantity','variance'))
            p.addOptional('units','dimensionless',...
                @(arg)validateattributes(arg,{'char'},{'row'},...
                'quantity','units'))
            p.parse(average,varargin{:});
            args = p.Results;
            x = x@double(args.average);
            x.average = double(x);
            x.variance = args.variance;
            x.stdev = sqrt(x.variance);
            x.relative = x.stdev./x.average;
            x.units = args.units;
        end
        function disp(x)
            % DISP Display quantity.
            if ismatrix(x)
                fmt1 = '\t%g +/- %g [%s]';
                fmtN = '%s, %g +/- %g [%s]';
                dims = size(x);
                % 1st row & column string
                F = subsref(x,substruct('()',{1,1}));
                sc = sprintf(fmt1,F.average,F.stdev,F.units);
                % 1st row string
                for n = 2:dims(2)
                    F = subsref(x,substruct('()',{1,n}));
                    sc = sprintf(fmtN,sc,F.average,F.stdev,F.units);
                end
                sr = sprintf('%s;\n',sc);
                for m = 2:dims(1)
                    F = subsref(x,struct('type',{'()'},'subs',{{m,1}}));
                    sc = sprintf(fmt1,F.average,F.stdev,F.units);
                    for n = 2:dims(2)
                        F = subsref(x,substruct('()',{m,n}));
                        sc = sprintf(fmtN,sc,F.average,F.stdev,F.units);
                    end
                    sr = sprintf('%s%s;\n',sr,sc);
                end
                fprintf('%s',sr)
            else
                disp@double(x)
            end
        end
        function F = transpose(x)
            F = Quantities.quantity(transpose@double(x.average),...
                transpose(x.variance),x.units);
        end
        function F = ctranspose(x)
            F = Quantities.quantity(ctranspose@double(x.average),...
                ctranspose(x.variance),x.units);
        end
        function F = subsref(x,s)
            F = x;
            for s_ = s
                if isa(F,'Quantities.quantity')
                    switch s_.type
                        case '.'
                            F = F.(s_.subs);
                        case '()'
                            F = Quantities.quantity(subsref(F.average,s_), ...
                                subsref(F.variance,s_),F.units);
                    end
                else
                    F = subsref(F,s_);
                end
            end
        end
        function F = subsasgn(x,idx,y)
            F = Quantities.quantity(subsasgn(x.average,idx,y.average), ...
                subsasgn(x.variance,idx,y.variance),...
                subsasgn(x.units,idx,y.units));
        end
        function F = horzcat(varargin)
            avg_ = cellfun(@(x)x.average,varargin,'UniformOutput',false);
            var_ = cellfun(@(x)x.variance,varargin,'UniformOutput',false);
            units_ = cellfun(@(x)x.units,varargin,'UniformOutput',false);
            F = Quantities.quantity([avg_{:}],[var_{:}],[units_{:}]);
        end
        function F = vertcat(varargin)
            avg_ = cellfun(@(x)x.average,varargin,'UniformOutput',false);
            var_ = cellfun(@(x)x.variance,varargin,'UniformOutput',false);
            units_ = cellfun(@(x)x.units,varargin,'UniformOutput',false);
            F = Quantities.quantity(vertcat(avg_{:}),vertcat(var_{:}),...
                vertcat(units_{:}));
        end
        function F = cat(dim,varargin)
            if dim==1
                F = vertcat(varargin{:});
            elseif dim==2
                F = horzcat(varargin{:});
            end
        end
        function F = binop(x,y,F,Fvar)
            % BINOP(X,Y,F,FVAR) Binary operation.
            %
            % Args
            %     X (double): First argument.
            %     Y (double): Second argument.
            %     F (double): Return value.
            %     FVAR (function handle): Calculates variance of F given X, Y,
            %         DX and DY.
            %
            % Returns:
            %     quantity: 
            % 
            if isa(x,'Quantities.quantity') && isa(y,'Quantities.quantity')
                F = Quantities.quantity(F,...
                    Fvar(x.average,y.average,x.variance,y.variance));
            elseif isa(x,'Quantities.quantity')
                F = Quantities.quantity(F,x.variance);
            else
                F = Quantities.quantity(F,y.variance);
            end
        end
        function F = plus(x,y)
            % F = x+y
            % dF^2 = dx.^2+dy.^2
            F = binop(x,y,plus@double(x,y),@(x,y,dx,dy)dx.^2+dy.^2);
        end
        function F = minus(x,y)
            % F = x-y
            % dF^2 = dx.^2-dy.^2
            F = binop(x,y,minus@double(x,y),@(x,y,dx,dy)dx.^2-dy.^2);
        end
        function F = times(x,y)
            % F = x.*y
            % dF^2 = y.^2.*dx.^2+x.^2.*dy.^2
            F = binop(x,y,times@double(x,y),...
                @(x,y,dx,dy)y.^2.*dx.^2+x.^2.*dy.^2);
        end
        function F = mtimes(x,y)
            % F_ik = x_ij*y_jk = x_i1*y_1k + x_i2*y_2k + x_i3*y_3k
            % dF_ik^2 = dx_ij.^2*y_jk.^2+x_ij.^2*dy_jk.^2
            function dF = Fvar(x,y,dx,dy)
                dF = zeros(size(x,1),size(y,2));
                for idx = 1:size(x,1)
                    for kdx = 1:size(y,2)
                        dF(idx,kdx) = dx(idx,:).^2*y(:,kdx).^2+...
                            x(idx,:).^2*dy(:,kdx).^2;
                    end
                end
            end
            F = binop(x,y,mtimes@double(x,y),@Fvar);
        end
        function F = power(x,y)
            % F = x.^y
            % dF^2 = y.^2.*dx.^2+x.^2.*dy.^2
            F = binop(x,y,power@double(x,y),...
                @(x,y,dx,dy)(y.*x.^(y-1)).^2.*dx.^2+(log(x).*x.^y).^2.*dy.^2);
        end
        function F = rdivide(x,y)
            % F = x./y
            % dF^2 = 1./y.^2.*dx.^2-x.^2./y.^4.*dy.^2
            F = binop(x,y,rdivide@double(x,y),...
                @(x,y,dx,dy)1./y.^2.*dx.^2-x.^2./y.^4.*dy.^2);
        end
        function F = ldivide(x,y)
            % F = x.\y = y./x
            % dF^2 = 1./x.^2.*dy.^2-y.^2./x.^4.*dx.^2
            F = binop(x,y,ldivide@double(x,y),...
                @(x,y,dx,dy)1./x.^2.*dy.^2-y.^2./x.^4.*dx.^2);
        end
        function F = uplus(x)
            % F = +x
            F = Quantities.quantity(uplus@double(x),x.variance);
        end
        function F = uminus(x)
            % F = -x
            F = Quantities.quantity(uminus@double(x),x.variance);
        end
        function F = sin(x)
            % F = sin(x)
            % dF^2 = cos(x)^2*dx^2
            F = Quantities.quantity(sin@double(x), ...
                cos(x.average).^2.*x.variance.^2);
        end
        function F = cos(x)
            % F = cos(x)
            % dF^2 = -sin(x)^2*dx^2
            F = Quantities.quantity(cos@double(x), ...
                (-sin(x.average)).^2.*x.variance.^2);
        end
        function F = log(x)
            % F = log(x)
            % dF^2 = (1/x)^2*dx^2
            F = Quantities.quantity(log@double(x), ...
                1./x.average.^2.*x.variance.^2);
        end
        function F = log2(x)
            % F = log(x)
            % dF^2 = (1/x/log(2))^2*dx^2
            F = Quantities.quantity(log2@double(x), ...
                1./(log(2)*x.average).^2.*x.variance.^2);
        end
        function F = log10(x)
            % F = log(x)
            % dF^2 = (1/x/log(10))^2*dx^2
            F = Quantities.quantity(log10@double(x), ...
                1./(log(10)*x.average).^2.*x.variance.^2);
        end
    end
end