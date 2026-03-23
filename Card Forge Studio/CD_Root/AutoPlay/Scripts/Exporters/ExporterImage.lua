return class("ExporterImage",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --ExporterImage = function(this, sAuthCode) end, --static constructor (runs after class object creation)
    },
    {--PRIVATE

    },
    {--PROTECTED

    },
    {--PUBLIC
        ExporterImage = function(this, cdat, super)
            super();
        end,
    },
    Exporter,   --extending class
    true,       --if the class is final
    nil         --interface(s) (either nil, or interface(s))
);
