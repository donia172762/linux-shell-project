#!/bin/bash
#donia said
#khadija

# Global variables
LOG_FILE=""
LATE_THRESHOLD=5 
EARLY_THRESHOLD=5 

# Color codes for better output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display the main menu
display_menu() {
    echo -e "========================================"
    echo -e "     Online Course Log Analyzer    "
    echo -e "========================================"
    echo "1. Number of sessions per course"
    echo "2. Average attendance per course"
    echo "3. List of absent students per course"
    echo "4. List of late arrivals per session"
    echo "5. List of students leaving early"
    echo "6. Average attendance time per student per course"
    echo "7. Average number of attendances per instructor"
    echo "8. Most frequently used tool"
    echo "9. Exit"
    echo -e "========================================"
}

# Function to validate if log file exists and is readable
validate_log_file() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "Error: Log file '$LOG_FILE' not found!  "
        return 1
    fi
    if [[ ! -r "$LOG_FILE" ]]; then
        echo -e "Error: Cannot read log file '$LOG_FILE'"
        return 1
    fi
    return 0
}

# Function 1: Number of sessions per course
count_sessions_per_course() {
    echo -e "=== Number of Sessions Per Course ==="
    read -p "Enter CourseID: " course_id
    
    if [[ -z "$course_id" ]]; then
        echo -e "Error: CourseID cannot be empty!"
        return 1
    fi
    
    # Count unique sessions for the given course
    session_count=$(awk -F',' -v course="$course_id" '
        $6 == course { sessions[$9] = 1 }
        END { print length(sessions) }
    ' "$LOG_FILE")
    
    if [[ $session_count -eq 0 ]]; then
        echo -e "No sessions found for course: $course_id"
    else
        echo -e "Course $course_id has $session_count session(s)"
    fi
}

# Function 2: Average attendance per course
average_attendance_per_course() {
    echo -e "=== Average Attendance Per Course ==="
    read -p "Enter CourseID: " course
    
    if [[ -z "$course" ]]; then
        echo -e "Error: CourseID cannot be empty!"
        return 1
    fi
    
    total_sessions=$(awk -F',' -v c="$course" '$6==c {print $9}' "$LOG_FILE" | sort -u | wc -l)
    total_attendance=$(awk -F',' -v c="$course" '$6==c {print $2}' "$LOG_FILE" | wc -l)

    if [ $total_sessions -eq 0 ]; then
        echo -e "No sessions found for course $course"
        return
    fi

    avg=$((total_attendance / total_sessions))
    echo -e "${GREEN}Average attendance per session for course $course = $avg${NC}"
}

# Function 3: List of absent students per course
list_absent_students() {
    echo -e "=== List of Absent Students Per Course ==="
    read -p "Enter CourseID: " course
    
    if [[ -z "$course" ]]; then
        echo -e "Error: CourseID cannot be empty!"
        return 1
    fi
    
    reg_file="${course}.csv"

    if [ ! -f "$reg_file" ]; then
        echo -e "Registration file $reg_file not found!"
        echo -e "Note: Create a registration file named ${course}.csv with StudentID,FirstName,LastName"
        return
    fi

    # Create temporary files
    temp_dir=$(mktemp -d)
    registered_file="$temp_dir/registered.txt"
    attended_file="$temp_dir/attended.txt"
    absent_file="$temp_dir/absent.txt"

    # Registered students
    awk -F',' '{print $1","$2","$3}' "$reg_file" | sort > "$registered_file"

    # Students who attended
    awk -F',' -v c="$course" '$6==c {print $2}' "$LOG_FILE" | sort -u > "$attended_file"

    # Extract absent students
    awk -F',' 'NR==FNR {a[$1]; next} !($1 in a)' "$attended_file" "$registered_file" > "$absent_file"

    echo -e "${BLUE}Absent students in course $course:${NC}"
    if [[ -s "$absent_file" ]]; then
        cat "$absent_file"
    else
        echo -e "No absent students found - all registered students attended!"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function 4: List of late arrivals per session
list_late_arrivals() {
    echo -e "=== Late Arrivals Per Session ==="
    read -p "Enter CourseID: " course_id
    read -p "Enter SessionID: " session_id
    read -p "Enter late threshold in minutes (default: $LATE_THRESHOLD): " threshold
    
    # Use default if no threshold provided
    if [[ -z "$threshold" ]]; then
        threshold=$LATE_THRESHOLD
    fi
    
    if [[ -z "$course_id" || -z "$session_id" ]]; then
        echo -e "Error: CourseID and SessionID cannot be empty!"
        return 1
    fi
    
    echo -e "Students who arrived more than $threshold minutes late:$"
    echo "StudentID | Name | Start Time | Actual Join Time | Minutes Late"
    echo "------------|----------|------------|---------------|------------------"
    
    # Find late arrivals
    awk -F',' -v course="$course_id" -v session="$session_id" -v threshold="$threshold" '
    function time_to_minutes(time_str) {
        # Remove leading/trailing spaces
        gsub(/^[ \t]+|[ \t]+$/, "", time_str)
        # Handle format: HH:MM or space HH:MM
        if (match(time_str, /([0-9]{1,2}):([0-9]{2})/, arr)) {
            return arr[1] * 60 + arr[2]
        }
        return 0
    }
    
    $6 == course && $9 == session {
        # Parse start time and student join time
        start_minutes = time_to_minutes($7)
        join_minutes = time_to_minutes($10)
        
        # Calculate lateness
        late_minutes = join_minutes - start_minutes
        
        if (late_minutes >= threshold) {
            printf "%-9s | %s %s | %s | %s | %d\n", $2, $3, $4, $7, $10, late_minutes
        }
    }
    ' "$LOG_FILE"
}

# Function 5: List of students leaving early
list_early_leavers() {
    echo -e "=== List of Students Leaving Early ==="
    read -p "Enter CourseID: " course
    read -p "Enter SessionID: " session
    read -p "Enter early leave threshold in minutes (default: $EARLY_THRESHOLD): " Y
    
    if [[ -z "$Y" ]]; then
        Y=$EARLY_THRESHOLD
    fi
    
    if [[ -z "$course" || -z "$session" ]]; then
        echo -e "${RED}Error: CourseID and SessionID cannot be empty!${NC}"
        return 1
    fi

    echo -e "${BLUE}Students who left more than $Y minutes early:${NC}"
    echo "StudentID | Name | Expected End | Actual Leave | Minutes Early"
    echo "------------|----------|------------|---------------|------------------"

    awk -F',' -v c="$course" -v s="$session" -v y="$Y" '
    function time_to_minutes(time_str) {
        gsub(/^[ \t]+|[ \t]+$/, "", time_str)
        if (match(time_str, /([0-9]{1,2}):([0-9]{2})/, arr)) {
            return arr[1] * 60 + arr[2]
        }
        return 0
    }
    
    function minutes_to_time(minutes) {
        hours = int(minutes / 60)
        mins = minutes % 60
        return sprintf("%02d:%02d", hours, mins)
    }
    
    $6==c && $9==s {
        start_minutes = time_to_minutes($7)
        end_minutes = start_minutes + $8   # Official end time
        leave_minutes = time_to_minutes($11)
        
        early_minutes = end_minutes - leave_minutes
        
        if (early_minutes >= y) {
            printf "%-9s | %s %s | %s | %s | %d\n", $2, $3, $4, minutes_to_time(end_minutes), $11, early_minutes
        }
    }' "$LOG_FILE"
}

# Function 6: Average attendance time per student per course
average_attendance_time() {
    echo -e "=== Average Attendance Time Per Student ==="
    read -p "Enter CourseID: " course_id
    
    if [[ -z "$course_id" ]]; then
        echo -e "Error: CourseID cannot be empty!"
        return 1
    fi
    
    echo -e "${BLUE}Average attendance time for course $course_id:${NC}"
    echo "StudentID | Name | Average Minutes Attended"
    echo "----------|------|-------------------"
    
    # Calculate average attendance time per student
    awk -F',' -v course="$course_id" '
    function time_to_minutes(time_str) {
        # Remove leading/trailing spaces
        gsub(/^[ \t]+|[ \t]+$/, "", time_str)
        if (match(time_str, /([0-9]{1,2}):([0-9]{2})/, arr)) {
            return arr[1] * 60 + arr[2]
        }
        return 0
    }
    
    $6 == course {
        student_id = $2
        name = $3 " " $4
        
        # Calculate attendance time for this session
        join_time = time_to_minutes($10)
        leave_time = time_to_minutes($11)
        attendance_time = leave_time - join_time
        
        if (attendance_time > 0) {
            total_time[student_id] += attendance_time
            session_count[student_id]++
            student_names[student_id] = name
        }
    }
    
    END {
        for (student in total_time) {
            avg_time = total_time[student] / session_count[student]
            printf "%-9s | %-20s | %.1f\n", student, student_names[student], avg_time
        }
    }
    ' "$LOG_FILE"
}

# Function 7: Average number of attendances per instructor
average_attendance_per_instructor() {
    echo -e "${YELLOW}=== Average Number of Attendances Per Instructor ===${NC}"
    
    temp_dir=$(mktemp -d)
    temp_file="$temp_dir/temp.txt"
    
    awk -F',' '{print $5","$9","$2}' "$LOG_FILE" | sort -u > "$temp_file"

    awk -F',' '{
        key=$1
        session=$2
        student=$3
        count[key","session]++
        total[key]++
        sessions[key][session]=1
    } END {
        for (k in total) {
            split(k,parts,",")
            instructor=parts[1]
            ns=0
            for (s in sessions[instructor]) ns++
            avg = total[k]/ns
            printf "Instructor %s: average attendance = %.1f students per session\n", instructor, avg
        }
    }' "$temp_file"
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function 8: Most frequently used tool
most_used_tool() {
    echo -e "${YELLOW}=== Most Frequently Used Tool ===${NC}"
    
    # Count tool usage
    result=$(awk -F',' '
    {
        tool_count[$1]++
    }
    END {
        zoom_count = tool_count["Zoom"]
        teams_count = tool_count["Teams"]
        
        printf "Zoom: %d sessions\n", zoom_count
        printf "Teams: %d sessions\n", teams_count
        
        if (zoom_count > teams_count) {
            printf "Most used tool: Zoom (%d sessions)\n", zoom_count
        } else if (teams_count > zoom_count) {
            printf "Most used tool: Teams (%d sessions)\n", teams_count
        } else {
            printf "Both tools are used equally (%d sessions each)\n", zoom_count
        }
    }
    ' "$LOG_FILE")
    
    echo -e "${GREEN}$result${NC}"
}

# Function to initialize the script
initialize_script() {
    echo -e "========================================"
    echo -e "     Online Course Log Analyzer     "
    echo -e "======================================== "
    
    # Get log file path
    read -p "Enter the path to the log file: " LOG_FILE
    
    # Validate log file
    if ! validate_log_file; then
        exit 1
    fi
    
    echo -e "${GREEN}Log file loaded successfully!${NC}"
    echo -e "${YELLOW}Note: For task 3 (absent students), make sure you have registration files named CourseID.csv${NC}"
}

# Main script execution
main() {
    # Initialize script
    initialize_script
    
    # Main menu loop
    while true; do
        echo ""
        display_menu
        read -p "Please select an option (1-9): " choice
        
        case $choice in
            1)
                count_sessions_per_course
                ;;
            2)
                average_attendance_per_course
                ;;
            3)
                list_absent_students
                ;;
            4)
                list_late_arrivals
                ;;
            5)
                list_early_leavers
                ;;
            6)
                average_attendance_time
                ;;
            7)
                average_attendance_per_instructor
                ;;
            8)
                most_used_tool
                ;;
            9)
                echo -e "Thank you for using Online Course Log Analyzer!"
                exit 0
                ;;
            *)
                echo -e "Invalid option! Please select 1-9."
                ;;
        esac
        
        # Ask if user wants to continue
        echo ""
        read -p "Press Enter to continue..." 
    done
}

# Run the main function
main