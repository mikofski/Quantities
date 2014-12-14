classdef unitRegistry < containers.Map
    properties
        unitsfile = fullfile(fileparts(mfilename('fullpath')),'default_en.xml')
    end
    methods
        function ureg = unitRegistry(unitsfile)
            ureg = ureg@containers.Map({'meter','inch','second'},...
                {Quantities.unit('meter','length',...
                Quantities.quantity(1,0,'meter'),{'m','meters'}),...
                Quantities.unit('inch','length',...
                Quantities.quantity(0.0254,0,'meter'),{'in','inches'}),...
                Quantities.unit('second','time',...
                Quantities.quantity(1,0,'second'),{'s','seconds'})});
            if nargin>1
                ureg.unitsfile = unitsfile;
            end
            xdoc = xmlread(ureg.unitsfile);
        end
    end
    properties (Constant)
        DEFAULT = Quantities.unitRegistry
    end
end
