% tests
L = Quantities.dimension('length');
T = Quantities.dimension('time');
M = Quantities.dimension('mass');
a = Quantities.dimension('acceleration',L./T.^2);
F = Quantities.dimension('force',M.*a);
kilo = Quantities.prefix('kilo',1000,{'k'});
deci = Quantities.prefix('deci',0.1,{'d'});
deca = Quantities.prefix('deca',1000,{'da'});
meter = Quantities.unit('meter',L,1,0,{'meters','metre','metres','m'});
inch = Quantities.unit('inch',L,0.0254.*meter,0,{'in','inches'});
second = Quantities.unit('second',T,1,0,{'s','seconds'});
gram = Quantities.unit('gram',M,1,0,{'g','grams'});
newton = Quantities.unit('Newton',F,kilo*gram.*meter./second.^2,0,...
    {'N','newtons'});
radian = Quantities.unit('radian',[],1,0,{'rad'});
degree = Quantities.unit('degree',[],Quantities.quantity(pi/180,'unit',radian),0,{'deg'});
