// =========================================================
// HUBNER EDU - INTERACTIVE JAVASCRIPT
// =========================================================

document.addEventListener('DOMContentLoaded', () => {
  // 1. Navbar Scroll Effect
  const navbar = document.querySelector('.navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 40) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  // 2. Accordion Interactive Toggle
  const accordionItems = document.querySelectorAll('.accordion-item');
  accordionItems.forEach(item => {
    const header = item.querySelector('.accordion-header');
    const body = item.querySelector('.accordion-body');

    header.addEventListener('click', () => {
      const isActive = item.classList.contains('active');

      // Close all other accordion items
      accordionItems.forEach(otherItem => {
        if (otherItem !== item) {
          otherItem.classList.remove('active');
          const otherBody = otherItem.querySelector('.accordion-body');
          if (otherBody) otherBody.style.maxHeight = null;
        }
      });

      // Toggle current item
      if (isActive) {
        item.classList.remove('active');
        body.style.maxHeight = null;
      } else {
        item.classList.add('active');
        body.style.maxHeight = body.scrollHeight + 'px';
      }
    });
  });

  // Open the first accordion item by default
  if (accordionItems.length > 0) {
    accordionItems[0].classList.add('active');
    const firstBody = accordionItems[0].querySelector('.accordion-body');
    if (firstBody) {
      firstBody.style.maxHeight = firstBody.scrollHeight + 'px';
    }
  }

  // 3. Testimonial Slider / Carousel
  const testimonials = [
    {
      quote: '"Hubner Edu adalah platform belajar terbaik yang pernah saya gunakan. Memantau Capaian Pembelajaran (CP), berdiskusi di kelas, dan mengerjakan kuis jadi sangat menyenangkan dan terstruktur!"',
      name: 'Dwaides Lorden',
      role: 'Siswa SMA Hubner Edu',
      img: 'images/testimonial_student.jpg'
    },
    {
      quote: '"Fitur pembuatan kurikulum dan kuis berbasis AI di Hubner Edu sangat menghemat waktu saya dalam menyiapkan materi belajar yang interaktif untuk siswa."',
      name: 'Budi Santoso, M.Pd',
      role: 'Guru Fisika & Kimia',
      img: 'images/tutor_male.jpg'
    },
    {
      quote: '"Tampilan aplikasinya sangat modern, bersih, dan cepat. Notifikasi jadwal belajar dan pengumpulan tugas real-time membuat kami sekelas selalu kompak."',
      name: 'Aisyah Putri',
      role: 'Siswa Kelas 12 IPA',
      img: 'images/hero_student_3.jpg'
    }
  ];

  let currentTestimonialIndex = 0;
  const quoteEl = document.querySelector('.testimonial-quote');
  const nameEl = document.querySelector('.testimonial-author h4');
  const roleEl = document.querySelector('.testimonial-author p');
  const imgEl = document.querySelector('.testimonial-avatar-wrapper img');
  const prevBtn = document.querySelector('.btn-arrow.prev');
  const nextBtn = document.querySelector('.btn-arrow.next');

  function updateTestimonial(index) {
    if (!quoteEl || !nameEl || !roleEl || !imgEl) return;
    
    // Smooth fade effect
    const card = document.querySelector('.testimonial-card-center');
    if (card) {
      card.style.opacity = '0.4';
      card.style.transform = 'scale(0.98)';
      setTimeout(() => {
        const item = testimonials[index];
        quoteEl.textContent = item.quote;
        nameEl.textContent = item.name;
        roleEl.textContent = item.role;
        imgEl.src = item.img;
        card.style.opacity = '1';
        card.style.transform = 'scale(1)';
      }, 200);
    }
  }

  if (prevBtn) {
    prevBtn.addEventListener('click', () => {
      currentTestimonialIndex = (currentTestimonialIndex - 1 + testimonials.length) % testimonials.length;
      updateTestimonial(currentTestimonialIndex);
    });
  }

  if (nextBtn) {
    nextBtn.addEventListener('click', () => {
      currentTestimonialIndex = (currentTestimonialIndex + 1) % testimonials.length;
      updateTestimonial(currentTestimonialIndex);
    });
  }

  // 4. Download Modal Trigger (Unduh Aplikasi)
  const downloadModal = document.getElementById('downloadModal');
  const downloadButtons = document.querySelectorAll('.trigger-download');
  const closeModalBtn = document.querySelector('.modal-close');

  downloadButtons.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      if (downloadModal) {
        downloadModal.classList.add('active');
      }
    });
  });

  if (closeModalBtn && downloadModal) {
    closeModalBtn.addEventListener('click', () => {
      downloadModal.classList.remove('active');
    });

    downloadModal.addEventListener('click', (e) => {
      if (e.target === downloadModal) {
        downloadModal.classList.remove('active');
      }
    });
  }

  // 5. Video Demo Modal / Trigger
  const playVideoBtn = document.querySelector('.btn-play-video');
  if (playVideoBtn) {
    playVideoBtn.addEventListener('click', () => {
      if (downloadModal) {
        downloadModal.classList.add('active');
      }
    });
  }
});
