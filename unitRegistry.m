classdef unitRegistry < containers.Map
    properties (SetAccess=private)
        unitsfile = fullfile(fileparts(mfilename('fullpath')),'default_en.xml')
        prefixes = {} % cell string of prefix keys
        dimensions = {} % cell string of dimension keys
        units = {} % cell string of unit keys
        constants = {} % cell string of constant keys
    end
    properties (Constant)
        DEFAULT = Quantities.unitRegistry
    end
    methods
        function ureg = unitRegistry(unitsfile)
%             L = Quantities.dimension('length');
%             T = Quantities.dimension('time');
%             M = Quantities.dimension('mass');
%             A = Quantities.dimension('area',L.^2);
%             meter = Quantities.unit('meter',L,1,{'meters','metre','metres','m'});
%             inch = Quantities.unit('inch',L,0.0254.*meter,{'in','inches'});
%             second = Quantities.unit('second',T,1,{'s','seconds'});
%             kilogram = Quantities.unit('kilogram',M,1,{'kg','kilograms'});
%             ureg = ureg@containers.Map({Quantities.unit.DIMENSIONLESS.name,...
%                 'meter','inch','second','kilogram',},...
%                 {Quantities.unit.DIMENSIONLESS,meter,inch,second,kilogram});
            ureg = ureg@containers.Map({Quantities.unit.DIMENSIONLESS.name},...
                {Quantities.unit.DIMENSIONLESS});
            if nargin>0
                ureg.unitsfile = unitsfile;
            end
            if exist(ureg.unitsfile,'file')==0
                return
            end
            xdoc = xmlread(ureg.unitsfile);
            xroot = xdoc.getDocumentElement;
            % prefixes
            xprefixes = xroot.getElementsByTagName('prefix');
            for idx = 0:xprefixes.getLength-1
                xprefix = xprefixes.item(idx);
                name = char(xprefix.getAttribute('name'));
                ureg.prefixes{idx+1} = name;
            end
            % dimensions
            xdims = xroot.getElementsByTagName('dimension');
            attrs = struct('name',{'name','value'},'default',{'derived',1},...
                'hook',{@char,@ureg.get_value});
            for idx = 0:xdims.getLength-1
                xdim = xdims.item(idx);
                retv = Quantities.unitRegistry.reg_parser(xdim,attrs);
                dim = Quantities.dimension(retv{:});
                subsasgn(ureg,substruct('()',{dim.name}),dim);
                ureg.dimensions{idx+1} = dim.name;
            end
            % units
            xunits = xroot.getElementsByTagName('unit');
            for idx = 0:xunits.getLength-1
                xunit = xunits.item(idx);
                name = char(xunit.getAttribute('name'));
                dimensionality = xunit.getAttribute('dimensionality');
                if dimensionality.isEmpty
                    dimensionality = [];
                elseif ureg.isKey(char(dimensionality))
                    dimensionality = subsref(ureg,substruct('()',char(dimensionality)));
                else
                    dimensionality = Quantities.dimension(char(dimensionality));
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
                                if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
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
                ureg.units{idx+1} = name; % add name to units cellstring
            end
        end
        function F = subsref(ureg,s)
            switch s(1).type
                case '()'
                    % search prefixes
                    s_prefix = substruct('.','prefixes');
                    for p = subsref@containers.Map(ureg,s_prefix);
                        regprefix = subsref@containers.Map(ureg,...
                            substruct('()',p(1)));
                        if any(strncmp(s(1).subs,regprefix,numel(regprefix)));
                            %do something
                        elseif any(strncmp(s(1).subs,regprefix.alias,1));
                            %do something
                        end
                    end
                    try
                        F = subsref@containers.Map(ureg,s);
                    catch ME
                        if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                            rethrow(ME)
                        end
                        % loop through units and compare s.subs to aliases
                        s_unit = substruct('.','units');
                        for u = subsref@containers.Map(ureg,s_unit);
                            aliases = subsref@containers.Map(ureg,...
                                substruct('()',u(1),'.',{'aliases'}));
                            if any(strcmp(s(1).subs,aliases))
                                s(1).subs = u(1);
                                F = subsref@containers.Map(ureg,s);
                                break
                            end
                        end
                    end
                otherwise
                    F = subsref@containers.Map(ureg,s);
            end
        end
        function value = get_value(ureg,value)
            [v,d] = Quantities.unit.parse_name(char(value));
            value = 1;
            for idx = 1:numel(v)
                val = str2double(v{idx});
                if isnan(val)
                    val = strtrim(v{idx});
                    try
                        val = subsref(ureg,substruct('()',val));
                    catch ME
                        if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                            rethrow(ME)
                        end
                        error('unitRegistry:value',...
                            'Value refers to key that could not be found.')
                    end
                end
                value = value.*val.^d(idx);
            end
        end
    end
    methods (Static)
        function retv = reg_parser(xnode,attrs)
            % REG_PARSER Parser for registry files
            %
            % :param xnode: node in xml file
            % :param attrs: structure of attributes and defaults
            % :param taglist: name of tag used to list text
            
            num_attr = numel(attrs);
            retv = cell(1,num_attr);
            for idx = 1:num_attr
                retv{idx} = xnode.getAttribute(attrs(idx).name);
                if retv{idx}.isEmpty
                    retv{idx} = attrs(idx).default;
                else
                    retv{idx} = attrs(idx).hook(retv{idx});
                end
            end
        end
        function list = get_tag_text_list(xnode,tag)
            % GET_TAG_TEXT_LIST Get list of text content from tags.
            xlist = xnode.getElementsByTagName(tag);
            nlist = xlist.getLength;
            list = cell(1,nlist);
            for idx = 0:nlist-1
                list{idx+1} = char(xlist.item(idx).getTextContent);
            end
        end
    end
end
