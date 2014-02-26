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
        function F = subsref(x,s)
         F = x;
         for s_ = s
             switch s_.type
                 case '.'
                     F = F.(s_.subs);
                 case '()'
                     F = quantity(subsref(F.average,s_), ...
                         subsref(F.variance,s_));
             end
         end
        end
        function F = subsasgn(x,idx,y)
            F = quantity(subsasgn(x.average,idx,y.average), ...
                subsasgn(x.variance,idx,y.variance));
        end
        function F = plus(x,y)
            % F = x+y
            % dF^2 = dx.^2+dy.^2
            F = plus@double(x,y);
            if isa(y,'quantity')
                F = quantity(F,x.variance.^2+y.variance.^2);
            else
                F = quantity(F,x.variance);
            end
        end
        function F = minus(x,y)
            % F = x-y
            % dF^2 = dx.^2-dy.^2
            F = minus@double(x,y);
            if isa(y,'quantity')
                F = quantity(F,x.variance.^2-y.variance.^2);
            else
                F = quantity(F,x.variance);
            end
        end
        function F = times(x,y)
            % F = x.*y
            % dF^2 = y^2.*dx^2+x^2.*dy^2
            F = times@double(x,y);
            if isa(y,'quantity')
                F = quantity(F,y.average.^2.*x.variance.^2+ ...
                    x.average.^2.*y.variance.^2);
            else
                F = quantity(F,x.variance);
            end
        end
        function F = rdivide(x,y)
            % F = x./y
            % dF^2 = 1./y.^2.*dx.^2-x.^2./y.^4.*dy^2
            F = rdivide@double(x,y);
            if isa(y,'quantity')
                F = quantity(F,1./y.average.^2.*x.variance.^2- ...
                    x.average.^2./y.average.^4.*y.variance.^2);
            else
                F = quantity(F,x.variance);
            end
        end
        function F = ldivide(x,y)
            % F = x.\y = y./x
            % dF^2 = 1./x.^2.*dy.^2-y.^2./x.^4.*dx^2
            F = ldivide@double(x,y);
            if isa(y,'quantity')
                F = quantity(F,1./x.average.^2.*(y.variance).^2- ...
                    y.average.^2./x.average.^4.*(x.variance).^2);
            else
                F = quantity(F,x.variance);
            end
        end
        function F = uplus(x)
            % F = +x
            F = quantity(uplus@double(x),x.variance);
        end
        function F = uminus(x)
            % F = -x
            F = quantity(uminus@double(x),x.variance);
        end
        function F = sin(x)
            % F = sin(x)
            % dF^2 = cos(x)^2*dx^2
            F = quantity(sin@double(x), ...
                cos(x.average).^2.*x.variance.^2);
        end
        function F = cos(x)
            % F = cos(x)
            % dF^2 = -sin(x)^2*dx^2
            F = quantity(cos@double(x), ...
                (-sin(x.average)).^2.*x.variance.^2);
        end
        function F = log(x)
            % F = log(x)
            % dF^2 = (1/x)^2*dx^2
            F = quantity(log@double(x), ...
                1./x.average.^2.*x.variance.^2);
        end
        function F = log2(x)
            % F = log(x)
            % dF^2 = (1/x/log(2))^2*dx^2
            F = quantity(log2@double(x), ...
                1./(log(2)*x.average).^2.*x.variance.^2);
        end
        function F = log10(x)
            % F = log(x)
            % dF^2 = (1/x/log(10))^2*dx^2
            F = quantity(log10@double(x), ...
                1./(log(10)*x.average).^2.*x.variance.^2);
        end
    end
end