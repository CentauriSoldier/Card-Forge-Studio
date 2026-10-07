local _sClass       = "ExporterImage";
local _sMenuName    = "Image";
local _tReturns     = {
    [1] = {"boolean"},          --import row?
    [2] = {"string", "nil"},    --(optional) path
};

local function RowHandler()

end

return class(_sClass,
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end,        --static initializer (runs before class object creation)
        [_sClass] = function(cMe, sAuthCode)    --static constructor (runs after class object creation)
            Exporter.RegisterChildClass(cMe, sAuthCode, _sMenuName, _tReturns);
        end,
        Export = function(tRows)
            local pro = cdat.pro;
            --TODO Assertions

            for nRow, tRow in ipairs(tRows) do
                local returns = RowHandler(tRow);

                if (pro.CheckReturns(returns)) then

                end

            end

        end,
    },
    {--PRIVATE
        [_sClass] = function(this, cdat, super)
            super();
        end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    Exporter,   --extending class
    true,       --if the class is final
    nil         --interface(s) (either nil, or interface(s))
);
