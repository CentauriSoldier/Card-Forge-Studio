Path = {};



function Path.GetEndFolder(pPath)
    local sRet = "";

    if (rawtype(pPath) == "string" and pPath ~= "") then
        local tParts = String.SplitPath(pPath);

        if (rawtype(tParts) == "table") then
            local sFolder = rawtype(tParts.Folder) == "string" and tParts.Folder or "";
            local sName   = rawtype(tParts.Filename) == "string" and tParts.Filename or "";

            -- If the path ends in a slash, AMS puts the *last folder* in Filename
            if (sName ~= "") then
                sRet = sName;
            elseif (sFolder ~= "") then
                -- Otherwise extract from Folder
                if (sFolder:sub(-1) == "\\" or sFolder:sub(-1) == "/") then
                    sFolder = sFolder:sub(1, -2);
                end;

                local nPos = sFolder:match("^.*()\\") or sFolder:match("^.*()/");

                if (nPos) then
                    sRet = sFolder:sub(nPos + 1);
                else
                    sRet = sFolder;
                end

            end

        end

    end

    return sRet;
end

function Path.SortByEndFolder(a, b)
    local sGameA = Path.GetEndFolder(a);
    local sGameB = Path.GetEndFolder(b);
    return sGameA < sGameB;
end
