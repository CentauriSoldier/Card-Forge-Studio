local _sClass   = "ExporterImage";
local _sName    = "Image";
local _tReturns = {
    [1] = {"boolean"},          --import row?
    [2] = {"string", "nil"},    --(optional) path
};


return class(_sClass,
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        [_sClass] = function(cMe, sAuthCode)--static constructor (runs after class object creation)
            Exporter.RegisterChildClass(cMe, sAuthCode, _sName, _tReturns);
        end,
    },
    {--PRIVATE

    },
    {--PROTECTED

    },
    {--PUBLIC
        [_sClass] = function(this, cdat, super, sName, fExporter)
            --TODO Assertions

            --TODO LEFT OFF HERE


            super(sName, fExporter);
        end,
    },
    Exporter,   --extending class
    false,       --if the class is final
    nil         --interface(s) (either nil, or interface(s))
);
