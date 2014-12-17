classdef unitRegistry < containers.Map
    properties
        unitsfile = fullfile(fileparts(mfilename('fullpath')),'default_en.xml')
    end
    properties (Constant)
        DEFAULT = Quantities.unitRegistry
    end
    methods
        function ureg = unitRegistry(unitsfile)
            meter = Quantities.unit('meter','length',1,{'m','meters'});
            inch = Quantities.unit('inch','length',0.0254.*meter,{'in','inches'});
            second = Quantities.unit('second','time',1,{'s','seconds'});
            kilogram = Quantities.unit('kilogram','mass',1,{'kg','kilograms'});
            ureg = ureg@containers.Map({Quantities.unit.DIMENSIONLESS.name,...
                'meter','inch','second','kilogram',},...
                {Quantities.unit.DIMENSIONLESS,meter,inch,second,kilogram});
            if nargin>1
                ureg.unitsfile = unitsfile;
            end
            xdoc = xmlread(ureg.unitsfile);
        end
        function F = subsref(ureg,s)
            switch s.type
                case '.'
                    F = subsref@containers.Map(ureg,s);
                case '()'
                    try
                        F = subsref@containers.Map(ureg,s);
                    catch ME
                        if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                            rethrow(ME)
                        end
                        % loop through keys and compare s.subs to aliases
                        s_key = substruct('.','keys');
                        for k = subsref@containers.Map(ureg,s_key);
                            aliases = subsref@containers.Map(ureg,...
                                substruct('()',k(1),'.',{'aliases'}));
                            if any(strcmp(s.subs,aliases))
                                s_alias = substruct('()',k(1));
                                F = subsref@containers.Map(ureg,s_alias);
                            end
                        end
                    end
            end
        end
    end
end
