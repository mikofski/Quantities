classdef quantity < double
    properties (SetAccess = immutable)
        average % first moment = trap(x,y)/trap(x)
        variance % second moment = trap(x,y^2 - average^2)/trap(x)
        stdev % standard deviation = sqrt(variance)
        relative % relative standard deviation = standard deviation / average
    end
    methods
        function x = quantity(average,variance)
            x = x@double(average);
            x.average = double(x);
            x.variance = abs(variance);
            x.stdev = sqrt(x.variance);
            x.relative = x.stdev./x.average;
        end
        function disp(x)
            if isscalar(x)
                fprintf('\t%g +/- %g\n',x.average,x.stdev)
            elseif ismatrix(x)
                sr = '';
                dims = size(x);
                for m = 1:dims(1)
                    sc = sprintf('\t');
                    for n = 1:dims(2)
                        F = subsref(x,struct('type',{'()'},'subs',{{m,n}}));
                        sc = sprintf('%s%g +/- %g, ',sc,F.average,F.stdev);
                    end
                    sr = sprintf('%s%s\b\b;\n',sr,sc);
                end
                fprintf('%s',sr)
            else
                disp@double(x)
            end
        end
        function F = transpose(x)
            F = Quantities.quantity(transpose@double(x),transpose(x.variance));
        end
        function F = ctranspose(x)
            F = Quantities.quantity(ctranspose@double(x),ctranspose(x.variance));
        end
        function F = subsref(x,s)
         F = x;
         for s_ = s
             switch s_.type
                 case '.'
                     F = F.(s_.subs);
                 case '()'
                     F = Quantities.quantity(subsref(F.average,s_), ...
                         subsref(F.variance,s_));
             end
         end
        end
        function F = subsasgn(x,idx,y)
            F = Quantities.quantity(subsasgn(x.average,idx,y.average), ...
                subsasgn(x.variance,idx,y.variance));
        end
        function F = horzcat(varargin)
            avg_ = cellfun(@(x)x.average,varargin,'UniformOutput',false);
            var_ = cellfun(@(x)x.variance,varargin,'UniformOutput',false);
            F = Quantities.quantity([avg_{:}],[var_{:}]);
        end
        function F = vertcat(varargin)
            avg_ = cellfun(@(x)x.average,varargin,'UniformOutput',false);
            var_ = cellfun(@(x)x.variance,varargin,'UniformOutput',false);
            F = Quantities.quantity(vertcat(avg_{:}),vertcat(var_{:}));
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