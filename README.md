Quantities is an units and uncertainties package for MATLAB.

Installation
============
Clone or download the Quantities package to your MATLAB folder as `+Quantities`.

Usage
=====
1. Construct a units registry, which contains all units, constants, prefixes and
   dimensions.

    ```matlab
    >> ureg = Quantities.unitRegistry

    % ureg =

    %    Map with properties:

    %        Count: 279
    %      KeyType: char
    %    ValueType: any
    ```

2. Optionally pass `verbosity` parameter to `unitRegistry` to see list of units
   loaded.

    ```matlab
    >> ureg = Quantities.unitRegistry('v',2)
    ```

3. Units and constants can be indexed from the `unitRegsitry` using their name
   or alias. The `unit`, `constant` and `quantity` class all subclass to
   `double` so you can perform any operation on them. Combining a `double` with
   a `unit` creates a `quantity` class object.

    ```matlab
    >> T1 = 45*ureg('celsius')
    % T1 =
        45 ± 0 [degC];

    >> T2 = 123.3*ureg.degC
    % T2 =
        123.3 ± 0 [degC];
    ```

4. Perform operations. All units are converted to base.

    ```matlab
    >> T2.to_base
    % ans =
           396.45 ± 0 [kelvin];

    >> heat_loss = ureg.stefan_boltzmann_constant*(T1^4 - T2^4)
    % heat_loss =
        -819814 ± 0 [gram*second^-3];

    >> heat_loss = ureg.stefan_boltzmann_constant*(T1.to_base^4 - T2.to_base^4)
    % heat_loss =
        -819814 ± 0 [gram*second^-3];
    ```

5. Add uncertainty to quantities by calling constructor.

    ```matlab
    >> T3 = Quantities.quantity(56.2, 1.23, ureg.degC)
    % T3 =
        56.2 ± 1.23 [degC];

    >> heat_loss = ureg.stefan_boltzmann_constant*(T1^4 - T3^4)
    % heat_loss =
        -86228.1 ± 9966.66 [gram*second^-3];
    ```

6. Convert output to different units.

    ```matlab
    >> heat_loss_kg = heat_loss.convert(ureg.kg/ureg.s^3)
    % heat_loss_kg =
        -819.814 ± 0 [kilogram*second^-3];
    ```

7. Determine arbitrary conversion factor.

    ```matlab
    >> conversion_factor = ureg.mile.convert(ureg.km)
    % conversion_factor =
        1.60934 ± 0 [kilometer];
    ```
