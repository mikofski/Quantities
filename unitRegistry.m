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
            ureg = ureg@containers.Map({...
                'meter','inch','second',Quantities.unit.DIMENSIONLESS.name},...
                {meter,inch,second,Quantities.unit.DIMENSIONLESS},...
                'uniformValues', true);
            if nargin>1
                ureg.unitsfile = unitsfile;
            end
            xdoc = xmlread(ureg.unitsfile);
        end
    end
end
