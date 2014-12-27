classdef unitRegistry < containers.Map
    properties
        unitsfile = fullfile(fileparts(mfilename('fullpath')),'default_en.xml')
        prefixes = {} % cell string of prefixes keys
        units = {} % cell string of units keys
        constants = {} % cell string of constants keys
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
            xroot = xdoc.getDocumentElement;
            xunits = xroot.getElementsByTagName('unit');
            for i = 0:xunits.getLength-1
                xunit = xunits.item(i);
                name = char(xunit.getAttribute('name'));
                dimensionality = xunit.getAttribute('dimensionality');
                if dimensionality.isEmpty
                    dimensionality = '';
                else
                    dimensionality = char(dimensionality);
                end
                xaliases = xunit.getElementsByTagName('alias');
                num_aliases = xaliases.getLength;
                aliases = cell(1,num_aliases);
                for ai = 0:num_aliases-1
                    aliases{ai+1} = char(xaliases.item(ai).getTextContent);
                end
                value = xunit.getAttribute('value');
                if value.isEmpty
                    value = 1;
                else
                    [v,d] = Quantities.unit.parse_name(char(value));
                    value = 1;
                    for vi = 1:numel(v)
                        val = str2double(v{vi});
                        if isnan(val)
                            val = strtrim(v{vi});
                            try
                                val = subsref(ureg,substruct('()',val));
                            catch 
                                if strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                                    rethrow(ME)
                                end
                                error('unitRegistry:value',...
                                    'Value refers to key that could not be found.')
                            end
                        end
                        value = value.*val.^d(vi);
                    end
                end
                unit = Quantities.unit(name, dimensionality,value,aliases);
                subsasgn(ureg,substruct('()',{name}),unit);
            end
        end
        function F = subsref(ureg,s)
            switch s(1).type
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
                            if any(strcmp(s(1).subs,aliases))
                                s(1).subs = k(1);
                                F = subsref@containers.Map(ureg,s);
                                break
                            end
                        end
                    end
                otherwise
                    F = subsref@containers.Map(ureg,s);
            end
        end
    end
    methods (Static)
        function reg_parser(xnode,attr_list)
        % REG_PARSER Parser for registry files
        %
        % :param xnode: 
        end
    end
end
