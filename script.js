// Load data from LocalStorage
let xp = parseInt(localStorage.getItem('heroXP')) || 0;
let level = parseInt(localStorage.getItem('heroLevel')) || 1;
let xpToNextLevel = level * 100;

// Initialize the UI on load
window.onload = () => {
    updateUI();
};

function addTask() {
    const input = document.getElementById('taskInput');
    const taskText = input.value;
    if (taskText.trim() === "") return;

    const li = document.createElement('li');
    li.innerHTML = `
        <span>${taskText}</span>
        <button onclick="completeTask(this)">Done (+20 XP)</button>
    `;
    document.getElementById('taskList').appendChild(li);
    input.value = "";
}

function completeTask(button) {
    xp += 20;
    
    // Check for Level Up
    if (xp >= xpToNextLevel) {
        xp = xp - xpToNextLevel;
        level++;
        xpToNextLevel = level * 100;
        alert("🎉 LEVEL UP! You reached Level " + level);
    }

    saveData();
    updateUI();
    button.parentElement.remove();
}

function updateUI() {
    document.getElementById('xp').innerText = xp;
    document.getElementById('level').innerText = level;
    document.getElementById('next-level-xp').innerText = xpToNextLevel;
    
    // Calculate and update progress bar percentage
    const progressPercent = (xp / xpToNextLevel) * 100;
    document.getElementById('progress-bar').style.width = progressPercent + "%";
}

function saveData() {
    localStorage.setItem('heroXP', xp);
    localStorage.setItem('heroLevel', level);
}

function resetGame() {
    if(confirm("Are you sure you want to reset your character? All levels and XP will be lost.")) {
        localStorage.clear();
        location.reload();
    }
}