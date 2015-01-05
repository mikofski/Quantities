classdef unitRegistry < containers.Map
    properties (SetAccess=private)
        unitsfile = fullfile(fileparts(mfilename('fullpath')),'default_en.xml')
        prefixes = {} % cell string of prefix keys
        dimensions = {} % cell string of dimension keys
        units = {} % cell string of unit keys
        constants = {} % cell string of constant keys
    end
    properties (Constant)
        DEFAULT = Quantities.unitRegistry('')
    end
    methods
        function ureg = unitRegistry(unitsfile)
            pi_const = Quantities.constant('pi',pi);
            L = Quantities.dimension('length');
            T = Quantities.dimension('time');
            M = Quantities.dimension('mass');
            a = Quantities.dimension('acceleration',L./T.^2);
            F = Quantities.dimension('force',M.*a);
            kilo = Quantities.prefix('kilo',1000,{'k'});
            deci = Quantities.prefix('deci',0.1,{'d'});
            deca = Quantities.prefix('deca',1000,{'da'});
            meter = Quantities.unit('meter',L,1,{'meters','metre','metres','m'});
            inch = Quantities.unit('inch',L,0.0254.*meter,{'in','inches'});
            second = Quantities.unit('second',T,1,{'s','seconds'});
            gram = Quantities.unit('gram',M,1,{'g','grams'});
            newton = Quantities.unit('Newton',F,kilo*gram.*meter./second.^2,...
                {'N','newtons'});
            ureg = ureg@containers.Map({Quantities.unit.DIMENSIONLESS.name,...
                'meter','inch','second','gram','length','time','mass',...
                'acceleration','force','newton','kilo','deci','deca','pi'},...
                {Quantities.unit.DIMENSIONLESS,meter,inch,second,gram,...
                L,T,M,a,F,newton,kilo,deci,deca,pi_const});
            ureg.prefixes = {'kilo','deci','deca'};
            ureg.constants = {'pi'};
            ureg.dimensions = {'length','time','mass','acceleration','force'};
            ureg.units = {'meter','inch','second','gram','newton'};
%             ureg = ureg@containers.Map({Quantities.unit.DIMENSIONLESS.name},...
%                 {Quantities.unit.DIMENSIONLESS});
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
            attrs = struct('name',{'name','value'},'default',{'',1},...
                'hook',{@char,@ureg.get_value});
            for idx = 0:xprefixes.getLength-1
                xprefix = xprefixes.item(idx);
                retv = Quantities.unitRegistry.reg_parser(xprefix,attrs);
                aliases = Quantities.unitRegistry.get_tag_text_list(xprefix,'alias');
                pre = Quantities.prefix(retv{:},aliases);
                subsasgn(ureg,substruct('()',{pre.name}),pre);
                ureg.prefixes{idx+1} = pre.name;
            end
            % dimensions
            xdims = xroot.getElementsByTagName('dimension');
            % uses same attributes from prefixes
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
                    dimensionality = subsref(ureg,substruct('()',{char(dimensionality)}));
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
                                val = subsref(ureg,substruct('()',{val}));
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
                    % if key not found, search for aliases and prefixes
                    try
                        F = subsref@containers.Map(ureg,s); % base class subsref
                    catch ME
                        % only catch MATLAB:Containers:Map:NoKey exception
                        if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                            rethrow(ME)
                        end
                        % search aliases
                        % loop through units and compare s.subs to aliases
                        s_unit = substruct('.','units');
                        for u = subsref@containers.Map(ureg,s_unit);
                            aliases = subsref@containers.Map(ureg,...
                                substruct('()',u,'.','aliases'));
                            if any(strcmp(s(1).subs,aliases))
                                s(1).subs = u;
                                F = subsref@containers.Map(ureg,s);
                                return
                            end
                        end
                        % search prefixes
                        s_prefix = substruct('.','prefixes');
                        for p = subsref@containers.Map(ureg,s_prefix);
                            u = [];
                            % check prefix and its aliases
                            prefix = subsref@containers.Map(ureg,...
                                substruct('()',p));
                            len_prefix = numel(prefix.name);
                            % get alias indices checking 1st letter
                            alias_idx = strncmp(s(1).subs,prefix.aliases,1);
                            if any(strncmp(s(1).subs,prefix.name,len_prefix));
                                % get unit name
                                u = s(1).subs{1}(len_prefix+1:end);
                            elseif any(alias_idx);
                                % get alias
                                prefix_alias = prefix.aliases(alias_idx);
                                assert(isscalar(alias_idx),...
                                    'unitRegistry:subsref',...
                                    'Prefix aliases can''t have same first letter.')
                                prefix_alias = prefix_alias{1};
                                % get unit name
                                u = s(1).subs{1}(numel(prefix_alias)+1:end);
                            end
                            % return if matching unit found without prefix
                            % get unit
                            % TODO: refactor to eliminate redundancy
                            if ~isempty(u)
                                try
                                    u = subsref@containers.Map(ureg,substruct('()',{u}));
                                catch ME
                                    % only catch MATLAB:Containers:Map:NoKey exception
                                    if ~strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                                        rethrow(ME)
                                    end
                                    % search aliases
                                    % loop through units and compare s.subs to aliases
                                    for reg_unit = subsref@containers.Map(ureg,s_unit);
                                        aliases = subsref@containers.Map(ureg,...
                                            substruct('()',reg_unit,'.','aliases'));
                                        if any(strcmp(u,aliases))
                                            u = subsref@containers.Map(ureg,...
                                                substruct('()',reg_unit));
                                            break
                                        end
                                    end
                                end
                                if isa(u,'Quantities.unit')
                                    F = prefix.*u;
                                    if numel(s)>1
                                        F = subsref(F,s(2:end));
                                    end
                                    return
                                end
                            end
                        end
                        throw(ME)
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
