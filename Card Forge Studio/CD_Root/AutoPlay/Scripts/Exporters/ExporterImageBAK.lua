local _sClass       = "ExporterImage";
local _tReturns     = {
    [1] = {"boolean"},          --import row?
    [2] = {"string", "nil"},    --(optional) path
};

return class(_sClass,
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        [_sClass] = function(cMe, sAuthCode)--static constructor (runs after class object creation)
            Exporter.RegisterChildClass(cMe, sAuthCode, _tReturns);
        end,
    },
    {--PRIVATE

    },
    {--PROTECTED

    },
    {--PUBLIC
        [_sClass] = function(this, cdat, super, tExporter)
            super(tExporter);
        end,
        Export = function(this, cdat, tRows)
            local pro           = cdat.pro;
            local fRowHandler   = pro.RowHandler;
            --TODO Assertions

            for nRow, tRow in ipairs(tRows) do
                local returns = fRowHandler(tRow);

                if (pro.CheckReturns(returns)) then

                end

            end

        end,

    },
    Exporter,   --extending class
    false,       --if the class is final
    nil         --interface(s) (either nil, or interface(s))
);
