function cat-image --description "Smart cat with image/video/PDF preview"
    for v in $argv
        if test -f $v
            set file_type (file --mime-type -b $v 2>/dev/null)
            switch $file_type
                case 'image/*'
                    viu $v
                case 'video/*'
                    # Show video thumbnail if ffmpegthumbnailer is available
                    if command -q ffmpegthumbnailer
                        set tmp_thumb (mktemp --suffix=.png)
                        ffmpegthumbnailer -i $v -o $tmp_thumb -s 0 2>/dev/null
                        viu $tmp_thumb
                        /usr/bin/rm -f $tmp_thumb
                    else
                        echo "Video: $v (install ffmpegthumbnailer for preview)"
                    end
                case 'application/pdf'
                    # Show first page of PDF if pdftotext is available
                    if command -q pdftotext
                        pdftotext -l 1 -layout $v - | bat --style=plain
                    else
                        echo "PDF: $v (install poppler for preview)"
                    end
                case '*'
                    bat $v
            end
        else
            echo "$v doesn't exist"
            return 1
        end
    end
end