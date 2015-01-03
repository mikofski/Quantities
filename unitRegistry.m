classdef unitRegistry < containers.Map
    properties (SetAccess=private)
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
            L = Quantities.dimension('length');
            T = Quantities.dimension('time');
            M = Quantities.dimension('mass');
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
            if exist(ureg.unitsfile,'file')==0
                return
            end
            xdoc = xmlread(ureg.unitsfile);
            xroot = xdoc.getDocumentElement;
            xunits = xroot.getElementsByTagName('unit');
            for idx = 0:xunits.getLength-1
                xunit = xunits.item(idx);
                name = char(xunit.getAttribute('name'));
                ureg.units{idx+1} = name; % add name to units cellstring
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
                            catch ME
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
                unit = Quantities.unit(name,dimensionality,value,aliases);
                subsasgn(ureg,substruct('()',{name}),unit);
            end
            xprefixes = xroot.getElementsByTagName('prefix');
            for idx = 0:xprefixes.getLength-1
                xprefix = xprefixes.item(idx);
                name = char(xprefix.getAttribute('name'));
                ureg.prefixes{idx+1} = name;
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
        function retv = reg_parser(xnode,attrs,taglist)
            % REG_PARSER Parser for registry files
            %
            % :param xnode: node in xml file
            % :param attrs: structure of attributes and defaults
            % :param taglist: name of tag used to list text
            
            num_attr = numel(attrs);
            retv = cell(1,num_attr);
            for idx = 1:num_attr
                retv{idx} = xnode.getAttribute(attr(idx).name);
                if retv{idx}.isEmpty
                    retv{idx} = attr(idx).default;
                else
                    retv{idx} = attr(idx).hook(retv);
                end
            end
            xlist = xnode.getElementsByTagName(taglist);
            nlist = xlist.getLength;
            retv{idx+1} = cell(1,nlist);
            for jdx = 0:nlist-1
                retv{idx+1}{jdx+1} = char(xlist.item(jdx).getTextContent);
            end
        end
    end
end
