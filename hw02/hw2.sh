#!/bin/sh

show_help() {
    echo "hw2.sh -p TASK_ID -t TASK_TYPE [-h]" >&2
    echo "" >&2
    echo "Available Options:" >&2
    echo "" >&2
    echo "-p: Task id" >&2
    echo "-t JOIN_NYCU_CSIT|MATH_SOLVER|CRACK_PASSWORD: Task type" >&2
    echo "-h: Show the script usage" >&2
}

handle_math_solver() {
    problem=$(echo "$1" | grep -Eo '([-]?[0-9]+) ([+-]) ([0-9]+)')
    if [ -z "$problem" ]; then
        echo "Invalid problem"
        return 1
    fi

    a=$(echo "$problem" | awk '{print $1}')
    operator=$(echo "$problem" | awk '{print $2}')
    b=$(echo "$problem" | awk '{print $3}')

    if [ "$a" -lt -10000 ] || [ "$a" -gt 10000 ] || [ "$b" -lt 0 ] || [ "$b" -gt 10000 ]; then
        echo "Invalid problem"
        return 1
    fi

    ans=$(echo "$a $operator $b" | bc)

    if [ "$ans" -lt -20000 ] || [ "$ans" -gt 20000 ]; then
        echo "Invalid problem"
        return 1
    fi

    echo "$ans"
}

handle_join_nycu_csit() {
    echo "I Love NYCU CSIT"
}

decrypt_caesar_cipher() {
    ciphertext="$1"
    shift_value=1
    
    while [ "$shift_value" -le 13 ]; do
        decrypted=""
        i=0
        while [ "$i" -lt "${#ciphertext}" ]; do
            char=$(echo "$ciphertext" | cut -c$((i+1)))
            case "$char" in
                [A-Za-z])
                    ascii=$(printf "%d" "'$char")
                        case "$char" in
                            [A-Z])
                                # decrypted_char=$(printf "\\$(printf '%o' $(( (ascii - 65 - shift_value + 26) % 26 + 65 )))");;
                                decrypted_char=$(awk -v ascii="$ascii" -v shift="$shift_value" 'BEGIN {
                                    decrypted_ascii = (ascii - 65 - shift + 26) % 26 + 65;
                                    printf "%c", decrypted_ascii;
                                }')
                                ;;
                            *)
                                # decrypted_char=$(printf "\\$(printf '%o' $(( (ascii - 97 - shift_value + 26) % 26 + 97 )))");;
                                decrypted_char=$(awk -v ascii="$ascii" -v shift="$shift_value" 'BEGIN {
                                    decrypted_ascii = (ascii - 97 - shift + 26) % 26 + 97;
                                    printf "%c", decrypted_ascii;
                                }')
                                ;;
                            esac
                    decrypted="$decrypted$decrypted_char"
                    ;;
                *)
                    decrypted="$decrypted$char"
                    ;;
            esac
            i=$(( i + 1 ))
        done
        if echo "$decrypted" | grep -qE '^NYCUNASA\{.*\}$'; then
            echo "$decrypted"
            return 1
        fi
        shift_value=$(( shift_value + 1 ))
    done

    echo "Invalid problem"
}

while getopts ":p:t:h" opt; do
    case $opt in
        p) TASK_ID=$OPTARG ;;
        t) TASK_TYPE=$OPTARG ;;
        h) show_help; exit 0 ;;
        ?) show_help; exit 1 ;;
    esac
done

### ---- For TEST ---- ###
if [ "$TEST" = 1 ]; then
    TASK_ID="1"
    TASK_TYPE="MATH_SOLVER"
    task_problem="-2139 / 6528"
    task_type="MATH_SOLVER"
    task_status="PENDING"
elif [ "$TEST" = 2 ]; then
    TASK_ID="2"
    TASK_TYPE="CRACK_PASSWORD"
    # task_problem="ALPHANFN{QfLWrLExdqgSufIi}" # “NYCUNASA{DsYJeYRkqdtFhsVv}
    # task_problem="QBFXQDVD{QcMXBVxFxlXAbJyK}" # NYCUNASA{NzJUYSuCuiUXyGvH}
    task_problem="QBFXADVD{QcMXBVxFxlXXbJyK}" # Invalid problem
    task_type="CRACK_PASSWORD"
    task_status="PENDING"
fi
### ----------------- ###

if [ -z "$TASK_ID" ] || [ -z "$TASK_TYPE" ]; then
    exit 1
fi

task=$(curl -s http://10.113.0.253/tasks/"$TASK_ID")
task_problem=$(echo "$task" | jq -r '.problem')
task_type=$(echo "$task" | jq -r '.type')
task_status=$(echo "$task" | jq -r '.status')

if [ "$task_status" = "PENDING" ]; then
    case $TASK_TYPE in
        MATH_SOLVER)
            if [ "$TASK_TYPE" != "$task_type" ]; then
                echo "Task type not match" >&2
                exit 1
            fi
            answer=$(handle_math_solver "$task_problem")
            ;;
        JOIN_NYCU_CSIT)
            if [ "$TASK_TYPE" != "$task_type" ]; then
                echo "Task type not match" >&2
                exit 1
            fi
            answer=$(handle_join_nycu_csit)
            ;;
        CRACK_PASSWORD)
            if [ "$TASK_TYPE" != "$task_type" ]; then
                echo "Task type not match" >&2
                exit 1
            fi
            answer=$(decrypt_caesar_cipher "$task_problem")
            ;;
        *)
            echo "Invalid task type" >&2
            exit 1
            ;;
    esac
fi

response=$(curl -s -X POST http://10.113.0.253/tasks/"$TASK_ID"/submit -d "{\"answer\":\"$answer\"}" -H "Content-Type: application/json")
echo "$task"
echo "$response"

if [ "$TEST" != 0 ]; then
    echo "$answer"
fi