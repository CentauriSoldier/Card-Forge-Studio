local _sClass   = "";
local _sName    = "";
local _tReturns = {
    [1] = {""},
};


return class(_sClass,
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --[_sClass] = function(this, sAuthCode) end, --static constructor (runs after class object creation)
    },
    {--PRIVATE

    },
    {--PROTECTED

    },
    {--PUBLIC
        [_sClass] = function(this, cdat, super)
            super(_sName, _tReturns);
        end,
    },
    Exporter,   --extending class
    false,       --if the class is final
    nil         --interface(s) (either nil, or interface(s))
);
